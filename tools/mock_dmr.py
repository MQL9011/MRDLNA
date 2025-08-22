#!/usr/bin/env python3
import argparse
import asyncio
import datetime
import logging
import os
import socket
import struct
import sys
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse


# Minimal UPnP AVTransport/RenderingControl Media Renderer for local testing
# - Responds to SSDP M-SEARCH for MediaRenderer and services
# - Serves device description and SCPD XMLs
# - Implements a subset of SOAP actions: SetAVTransportURI, Play, Pause, Stop,
#   Seek, GetTransportInfo, GetPositionInfo, SetVolume, GetVolume


MULTICAST_GRP = "239.255.255.250"
MULTICAST_PORT = 1900


def get_local_ip_for_outbound() -> str:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"


class RendererState:
    def __init__(self):
        self.transport_uri = ""
        self.transport_metadata = ""
        self.transport_state = "STOPPED"  # STOPPED | PLAYING | PAUSED_PLAYBACK
        self.track_duration_seconds = 0
        self.position_seconds = 0
        self.volume = 20
        self.mutex = threading.Lock()
        self.last_play_timestamp = None  # datetime when started/resumed

    def _now(self):
        return datetime.datetime.now(datetime.timezone.utc)

    def set_uri(self, uri: str, meta: str = ""):
        with self.mutex:
            self.transport_uri = uri
            self.transport_metadata = meta
            self.position_seconds = 0
            self.track_duration_seconds = 0
            self.transport_state = "STOPPED"
            self.last_play_timestamp = None

    def play(self):
        with self.mutex:
            if self.transport_state != "PLAYING":
                self.last_play_timestamp = self._now()
                self.transport_state = "PLAYING"

    def pause(self):
        with self.mutex:
            if self.transport_state == "PLAYING" and self.last_play_timestamp is not None:
                elapsed = (self._now() - self.last_play_timestamp).total_seconds()
                self.position_seconds += int(elapsed)
            self.transport_state = "PAUSED_PLAYBACK"
            self.last_play_timestamp = None

    def stop(self):
        with self.mutex:
            self.transport_state = "STOPPED"
            self.position_seconds = 0
            self.last_play_timestamp = None

    def seek(self, target_seconds: int):
        with self.mutex:
            self.position_seconds = max(0, target_seconds)
            if self.transport_state == "PLAYING":
                self.last_play_timestamp = self._now()

    def get_transport_info(self):
        with self.mutex:
            current_state = self.transport_state
        return current_state, "OK", "OK"

    def get_position_info(self):
        with self.mutex:
            position = self.position_seconds
            if self.transport_state == "PLAYING" and self.last_play_timestamp is not None:
                elapsed = (self._now() - self.last_play_timestamp).total_seconds()
                position += int(elapsed)
            duration = self.track_duration_seconds if self.track_duration_seconds > 0 else 0
            uri = self.transport_uri
        return duration, position, uri

    def set_volume(self, vol: int):
        with self.mutex:
            self.volume = max(0, min(100, vol))

    def get_volume(self):
        with self.mutex:
            return self.volume


def seconds_to_time_string(seconds: int) -> str:
    h = seconds // 3600
    m = (seconds % 3600) // 60
    s = seconds % 60
    return f"{h:02d}:{m:02d}:{s:02d}"


def build_device_description(base_url: str, friendly_name: str, udn: str) -> bytes:
    return f"""
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
    <friendlyName>{friendly_name}</friendlyName>
    <manufacturer>Mock</manufacturer>
    <modelName>MockRenderer</modelName>
    <UDN>uuid:{udn}</UDN>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:AVTransport</serviceId>
        <SCPDURL>/avtransport.xml</SCPDURL>
        <controlURL>/upnp/control/avtransport</controlURL>
        <eventSubURL>/upnp/event/avtransport</eventSubURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:RenderingControl</serviceId>
        <SCPDURL>/renderingcontrol.xml</SCPDURL>
        <controlURL>/upnp/control/renderingcontrol</controlURL>
        <eventSubURL>/upnp/event/renderingcontrol</eventSubURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:ConnectionManager:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:ConnectionManager</serviceId>
        <SCPDURL>/connectionmanager.xml</SCPDURL>
        <controlURL>/upnp/control/connectionmanager</controlURL>
        <eventSubURL>/upnp/event/connectionmanager</eventSubURL>
      </service>
    </serviceList>
    <presentationURL>{base_url}</presentationURL>
  </device>
 </root>
""".strip().encode("utf-8")


AVTRANSPORT_SCPD = b"""
<?xml version="1.0"?>
<scpd xmlns="urn:schemas-upnp-org:service-1-0">
  <specVersion><major>1</major><minor>0</minor></specVersion>
  <actionList>
    <action><name>SetAVTransportURI</name></action>
    <action><name>Play</name></action>
    <action><name>Pause</name></action>
    <action><name>Stop</name></action>
    <action><name>Seek</name></action>
    <action><name>GetTransportInfo</name></action>
    <action><name>GetPositionInfo</name></action>
  </actionList>
  <serviceStateTable/>
</scpd>
"""


RENDERINGCONTROL_SCPD = b"""
<?xml version="1.0"?>
<scpd xmlns="urn:schemas-upnp-org:service-1-0">
  <specVersion><major>1</major><minor>0</minor></specVersion>
  <actionList>
    <action><name>SetVolume</name></action>
    <action><name>GetVolume</name></action>
  </actionList>
  <serviceStateTable/>
</scpd>
"""


CONNECTIONMANAGER_SCPD = b"""
<?xml version="1.0"?>
<scpd xmlns="urn:schemas-upnp-org:service-1-0">
  <specVersion><major>1</major><minor>0</minor></specVersion>
  <actionList>
    <action><name>GetProtocolInfo</name></action>
  </actionList>
  <serviceStateTable/>
</scpd>
"""


def soap_envelope(body_xml: str, service: str) -> bytes:
    return f"""
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
 <s:Body>
  <u:{body_xml} xmlns:u="urn:schemas-upnp-org:service:{service}:1"/>
 </s:Body>
</s:Envelope>
""".strip().encode("utf-8")


class UPnPRequestHandler(BaseHTTPRequestHandler):
    server_version = "MockDMR/1.0"

    def log_message(self, fmt, *args):
        logging.info("HTTP %s - %s", self.address_string(), fmt % args)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/description.xml":
            self.send_response(200)
            self.send_header("Content-Type", "text/xml; charset=utf-8")
            self.end_headers()
            self.wfile.write(self.server.device_description)
            return
        if parsed.path == "/avtransport.xml":
            self.send_response(200)
            self.send_header("Content-Type", "text/xml; charset=utf-8")
            self.end_headers()
            self.wfile.write(AVTRANSPORT_SCPD)
            return
        if parsed.path == "/renderingcontrol.xml":
            self.send_response(200)
            self.send_header("Content-Type", "text/xml; charset=utf-8")
            self.end_headers()
            self.wfile.write(RENDERINGCONTROL_SCPD)
            return
        if parsed.path == "/connectionmanager.xml":
            self.send_response(200)
            self.send_header("Content-Type", "text/xml; charset=utf-8")
            self.end_headers()
            self.wfile.write(CONNECTIONMANAGER_SCPD)
            return
        self.send_error(404)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode("utf-8", errors="ignore")
        soap_action = self.headers.get("SOAPACTION", "").strip('"')
        logging.info("SOAPAction=%s", soap_action)

        if self.path == "/upnp/control/avtransport":
            response, ok = self._handle_avtransport(soap_action, body)
        elif self.path == "/upnp/control/renderingcontrol":
            response, ok = self._handle_renderingcontrol(soap_action, body)
        else:
            self.send_error(404)
            return

        if ok:
            self.send_response(200)
            self.send_header("Content-Type", "text/xml; charset=utf-8")
            self.end_headers()
            self.wfile.write(response)
        else:
            self.send_response(500)
            self.send_header("Content-Type", "text/xml; charset=utf-8")
            self.end_headers()
            self.wfile.write(response)

    def _handle_avtransport(self, action: str, body: str):
        st = self.server.state
        if action.endswith("#SetAVTransportURI"):
            import re
            m = re.search(r"<CurrentURI>(.*?)</CurrentURI>", body, re.S)
            uri = m.group(1) if m else ""
            m2 = re.search(r"<CurrentURIMetaData>(.*?)</CurrentURIMetaData>", body, re.S)
            meta = m2.group(1) if m2 else ""
            st.set_uri(uri, meta)
            return soap_envelope("SetAVTransportURIResponse", "AVTransport"), True
        if action.endswith("#Play"):
            st.play()
            return soap_envelope("PlayResponse", "AVTransport"), True
        if action.endswith("#Pause"):
            st.pause()
            return soap_envelope("PauseResponse", "AVTransport"), True
        if action.endswith("#Stop"):
            st.stop()
            return soap_envelope("StopResponse", "AVTransport"), True
        if action.endswith("#Seek"):
            import re
            m = re.search(r"<Target>(.*?)</Target>", body, re.S)
            target = m.group(1) if m else "00:00:00"
            try:
                h, m_, s = target.split(":")
                seconds = int(h) * 3600 + int(m_) * 60 + int(s)
            except Exception:
                seconds = 0
            st.seek(seconds)
            return soap_envelope("SeekResponse", "AVTransport"), True
        if action.endswith("#GetTransportInfo"):
            current, status, speed = st.get_transport_info()
            body_xml = (
                f"GetTransportInfoResponse>\n"
                f"   <CurrentTransportState>{current}</CurrentTransportState>\n"
                f"   <CurrentTransportStatus>{status}</CurrentTransportStatus>\n"
                f"   <CurrentSpeed>{speed}</CurrentSpeed>\n"
                f"</u:GetTransportInfoResponse"
            )
            return soap_envelope(body_xml, "AVTransport"), True
        if action.endswith("#GetPositionInfo"):
            duration, position, uri = st.get_position_info()
            body_xml = (
                f"GetPositionInfoResponse>\n"
                f"   <Track>1</Track>\n"
                f"   <TrackDuration>{seconds_to_time_string(duration)}</TrackDuration>\n"
                f"   <TrackMetaData></TrackMetaData>\n"
                f"   <TrackURI>{uri}</TrackURI>\n"
                f"   <RelTime>{seconds_to_time_string(position)}</RelTime>\n"
                f"   <AbsTime>{seconds_to_time_string(position)}</AbsTime>\n"
                f"   <RelCount>0</RelCount>\n"
                f"   <AbsCount>0</AbsCount>\n"
                f"</u:GetPositionInfoResponse"
            )
            return soap_envelope(body_xml, "AVTransport"), True
        return soap_error(401, "Invalid Action"), False

    def _handle_renderingcontrol(self, action: str, body: str):
        st = self.server.state
        if action.endswith("#SetVolume"):
            import re
            m = re.search(r"<DesiredVolume>(\d+)</DesiredVolume>", body)
            vol = int(m.group(1)) if m else 20
            st.set_volume(vol)
            return soap_envelope("SetVolumeResponse", "RenderingControl"), True
        if action.endswith("#GetVolume"):
            vol = st.get_volume()
            body_xml = (
                f"GetVolumeResponse>\n"
                f"   <CurrentVolume>{vol}</CurrentVolume>\n"
                f"</u:GetVolumeResponse"
            )
            return soap_envelope(body_xml, "RenderingControl"), True
        return soap_error(401, "Invalid Action"), False


def soap_error(code: int, description: str) -> bytes:
    return f"""
<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
 <s:Body>
  <s:Fault>
   <faultcode>s:Client</faultcode>
   <faultstring>UPnPError</faultstring>
   <detail>
    <UPnPError xmlns="urn:schemas-upnp-org:control-1-0">
     <errorCode>{code}</errorCode>
     <errorDescription>{description}</errorDescription>
    </UPnPError>
   </detail>
  </s:Fault>
 </s:Body>
</s:Envelope>
""".strip().encode("utf-8")


class MockHTTPServer(HTTPServer):
    def __init__(self, server_address, RequestHandlerClass, state: RendererState, device_description: bytes):
        super().__init__(server_address, RequestHandlerClass)
        self.state = state
        self.device_description = device_description


def start_http_server(bind_addr: str, port: int, state: RendererState, device_description: bytes):
    httpd = MockHTTPServer((bind_addr, port), UPnPRequestHandler, state, device_description)
    t = threading.Thread(target=httpd.serve_forever, daemon=True)
    t.start()
    logging.info("HTTP server started at http://%s:%d", bind_addr, port)
    return httpd


def build_ssdp_response_lines(location: str, st: str, usn: str):
    server = f"Mock/1.0 UPnP/1.1 MockDMR/1.0"
    return [
        "HTTP/1.1 200 OK",
        "CACHE-CONTROL: max-age=1200",
        f"DATE: {datetime.datetime.utcnow():%a, %d %b %Y %H:%M:%S GMT}",
        f"EXT:",
        f"LOCATION: {location}",
        f"SERVER: {server}",
        f"ST: {st}",
        f"USN: {usn}:: {st}",
        "\r\n",
    ]


def start_ssdp_responder(local_ip: str, http_port: int, udn: str, friendly_name: str):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        sock.bind(("", MULTICAST_PORT))
    except OSError:
        logging.warning("Port %d busy; SSDP responder may fail to bind.", MULTICAST_PORT)
        sock.bind(("0.0.0.0", 0))

    mreq = struct.pack("=4sl", socket.inet_aton(MULTICAST_GRP), socket.INADDR_ANY)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, mreq)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_IF, socket.inet_aton(local_ip))
    sock.setblocking(False)

    location = f"http://{local_ip}:{http_port}/description.xml"
    usn_base = f"uuid:{udn}"
    device_st = "urn:schemas-upnp-org:device:MediaRenderer:1"
    services = [
        device_st,
        "urn:schemas-upnp-org:service:AVTransport:1",
        "urn:schemas-upnp-org:service:RenderingControl:1",
        "urn:schemas-upnp-org:service:ConnectionManager:1",
        "upnp:rootdevice",
        "ssdp:all",
    ]

    async def responder_loop():
        logging.info("SSDP responder listening on %s:%d as '%s' (%s)", local_ip, MULTICAST_PORT, friendly_name, udn)
        loop = asyncio.get_running_loop()
        while True:
            try:
                data, addr = await loop.run_in_executor(None, sock.recvfrom, 65535)
            except BlockingIOError:
                await asyncio.sleep(0.05)
                continue
            except Exception as e:
                logging.error("SSDP recv error: %s", e)
                await asyncio.sleep(0.2)
                continue

            text = data.decode(errors="ignore")
            if "M-SEARCH" in text and "ssdp:discover" in text:
                st_line = next((l for l in text.splitlines() if l.upper().startswith("ST:")), "")
                st_val = st_line.split(":", 1)[1].strip() if ":" in st_line else ""
                target_services = services if st_val in ("ssdp:all", "") else [st_val]
                for st in target_services:
                    usn = usn_base if st == "upnp:rootdevice" else f"{usn_base}::{st}"
                    lines = build_ssdp_response_lines(location, st, usn)
                    payload = ("\r\n".join(lines)).encode("utf-8")
                    try:
                        sock.sendto(payload, addr)
                    except Exception:
                        pass

    t = threading.Thread(target=lambda: asyncio.run(responder_loop()), daemon=True)
    t.start()
    return sock


def main():
    parser = argparse.ArgumentParser(description="Mock DLNA/UPnP Media Renderer")
    parser.add_argument("--name", default="Mock Renderer")
    parser.add_argument("--bind", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8008)
    parser.add_argument("--uuid", default="c0ffee-5eed-0000-1111-222233334444")
    parser.add_argument("--log", default="info", choices=["debug", "info", "warning", "error"]) 
    args = parser.parse_args()

    logging.basicConfig(level=getattr(logging, args.log.upper()), format="[%(levelname)s] %(message)s")

    local_ip = get_local_ip_for_outbound()
    base_url = f"http://{local_ip}:{args.port}"
    state = RendererState()
    device_description = build_device_description(base_url, args.name, args.uuid)

    start_http_server(args.bind, args.port, state, device_description)
    start_ssdp_responder(local_ip, args.port, args.uuid, args.name)

    try:
        while True:
            time_sleep = 3600
            threading.Event().wait(time_sleep)
    except KeyboardInterrupt:
        print()
        logging.info("Shutting down")
        sys.exit(0)


if __name__ == "__main__":
    main()


