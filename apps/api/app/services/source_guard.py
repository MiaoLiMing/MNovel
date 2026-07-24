import ipaddress
import socket
from urllib.parse import urlparse


class UnsafeSourceUrl(ValueError):
    pass


def validate_public_source_url(value: str) -> str:
    parsed = urlparse(value)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise UnsafeSourceUrl("仅允许带主机名的 HTTP/HTTPS 地址")

    try:
        addresses = {item[4][0] for item in socket.getaddrinfo(parsed.hostname, None)}
    except socket.gaierror as exc:
        raise UnsafeSourceUrl("域名无法解析") from exc

    for address in addresses:
        ip = ipaddress.ip_address(address)
        if not ip.is_global:
            raise UnsafeSourceUrl("禁止访问本机、私网或链路本地地址")
    return value
