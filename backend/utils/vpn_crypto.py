"""
WebVPN URL 加解密工具

北师大 WebVPN (wengine-vpn) 使用 AES-128-CFB 加密内网域名。
加密参数：key = iv = "wrdvpnisthebest!"
URL 格式：https://onevpn.bnu.edu.cn/{protocol}/{hex(IV)+hex(AES(domain))}/{path}
"""

from binascii import hexlify, unhexlify

from Crypto.Cipher import AES

KEY = b"wrdvpnisthebest!"
IV = b"wrdvpnisthebest!"
VPN_HOST = "onevpn.bnu.edu.cn"


def encrypt_domain(domain: str) -> str:
    """加密域名，返回 hex(IV) + hex(密文)"""
    cipher = AES.new(KEY, AES.MODE_CFB, IV, segment_size=128)
    encrypted = cipher.encrypt(domain.encode("utf-8"))
    return hexlify(IV).decode() + hexlify(encrypted).decode()


def decrypt_domain(ciphertext_hex: str) -> str:
    """解密域名，输入为完整的 hex 字符串（含 IV 前缀）"""
    # 前 32 个 hex 字符是 IV（16 bytes）
    raw = unhexlify(ciphertext_hex[32:].encode("utf-8"))
    cipher = AES.new(KEY, AES.MODE_CFB, IV, segment_size=128)
    return cipher.decrypt(raw).decode("utf-8")


def to_vpn_url(internal_url: str) -> str:
    """
    将内网 URL 转换为 WebVPN 代理 URL
    
    示例：
    http://zyfw.bnu.edu.cn/student/xscj.stuckcj.my.jsp
    → https://onevpn.bnu.edu.cn/http/{encrypted_domain}/student/xscj.stuckcj.my.jsp
    """
    parts = internal_url.split("://")
    protocol = parts[0]  # http 或 https
    rest = parts[1].split("/", 1)
    domain = rest[0].split(":")[0]
    port_part = ""
    if ":" in rest[0]:
        port_part = f"-{rest[0].split(':')[1]}"
    path = rest[1] if len(rest) > 1 else ""
    
    encrypted = encrypt_domain(domain)
    return f"https://{VPN_HOST}/{protocol}{port_part}/{encrypted}/{path}"


def from_vpn_url(vpn_url: str) -> str:
    """
    将 WebVPN 代理 URL 还原为内网 URL
    
    示例：
    https://onevpn.bnu.edu.cn/http/7772647...d6562d/student/xscj.stuckcj.my.jsp
    → http://zyfw.bnu.edu.cn/student/xscj.stuckcj.my.jsp
    """
    # 去掉 https://onevpn.bnu.edu.cn/
    path = vpn_url.replace(f"https://{VPN_HOST}/", "")
    
    # 解析 protocol
    parts = path.split("/", 2)
    protocol_part = parts[0]  # http 或 http-port 或 https
    encrypted_domain = parts[1]
    remaining = parts[2] if len(parts) > 2 else ""
    
    # 解析协议和端口
    if "-" in protocol_part:
        protocol, port = protocol_part.split("-", 1)
        port_suffix = f":{port}"
    else:
        protocol = protocol_part
        port_suffix = ""
    
    domain = decrypt_domain(encrypted_domain)
    return f"{protocol}://{domain}{port_suffix}/{remaining}"


if __name__ == "__main__":
    # 验证加解密
    test_domain = "zyfw.bnu.edu.cn"
    encrypted = encrypt_domain(test_domain)
    print(f"加密 {test_domain} → {encrypted}")
    
    decrypted = decrypt_domain(encrypted)
    print(f"解密 → {decrypted}")
    
    assert decrypted == test_domain, "加解密验证失败！"
    print("✓ 加解密验证通过")
    
    # 测试 URL 转换
    internal = "http://zyfw.bnu.edu.cn/student/xscj.stuckcj.my.jsp"
    vpn = to_vpn_url(internal)
    print(f"\n内网 URL: {internal}")
    print(f"VPN URL:  {vpn}")
    
    restored = from_vpn_url(vpn)
    print(f"还原 URL: {restored}")
    assert restored == internal, "URL 转换验证失败！"
    print("✓ URL 转换验证通过")
