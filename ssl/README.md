# 自签名SSL证书说明
## 证书基础信息
- 生效时间：2000-01-01 00:00:00 GMT
- 过期时间：2099-12-31 00:00:00 GMT
- 有效时长：百年有效期
- 加密算法：RSA 4096位
- 证书信息：完全空白无域名、无机构、无个人信息
- 兼容环境：Nginx、Apache、宝塔面板、各类Linux服务端

## 文件列表
1. fullchain.pem  证书公钥文件
2. privkey.pem    证书私钥文件

## 适配解决问题
- 彻底解决 nginx ee key too small 密钥长度报错
- 适配新版OpenSSL严格加密策略
- 无时间限制长期使用，无需频繁更换证书

## Nginx部署配置示例
```nginx
listen 443 ssl;
ssl_certificate  证书存放路径/fullchain.pem;
ssl_certificate_key 证书存放路径/privkey.pem;
ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;
