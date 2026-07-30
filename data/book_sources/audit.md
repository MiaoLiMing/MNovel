# APK 书源审计报告

- 原始记录：1142
- APK SHA-256：`8d3194c81f07bd1ecb5faf241a8a0a16e70455535443cde11834c3d867429134`
- 资源 SHA-256：`f9c9779c6828d3b8f46f8e24d32c09b427bd4e0e3ccd74e9a0b8df8ab035b2ec`
- 资源大小：1939268 bytes

## 兼容性分类

| 分类 | 数量 |
| --- | ---: |
| `audio` | 7 |
| `compatible_core` | 925 |
| `incomplete` | 7 |
| `invalid_reference` | 1 |
| `login_required` | 33 |
| `script_required` | 169 |

说明：所有 APK 第三方源首次均保持关闭；只有完整链路检测通过后才应启用。

## 静态分析限制

APK 使用 360 加固，静态 DEX 只包含壳代码。兼容实现依据完整规则资产和可观察行为重写，未复制 APK 应用代码。
