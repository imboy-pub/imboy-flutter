# Geo 预览字体和许可

这两份字体随本机 Geo Web 预览和 Android QA 包分发。源数据和覆盖范围绑定消费者预览 manifest 的 SHA-256 `3080cbacca3246ead649fa951514731618f37bb14312299f9eb33d8119fef219`。

## IMBoyGeoCjk Regular

源字体为 Noto Sans CJK JP Regular 2.004，© 2014–2021 Adobe。官方 tag `Sans2.004` 的提交为 `523d033d6cb47f4a80c58a35753646f5c3608a78`，源 OTF SHA-256 为 `68a3fc98800b2a27b371f2fb79991daf3633bd89309d4ffaa6946fd587f375b5`。 [源字体](https://raw.githubusercontent.com/notofonts/noto-cjk/523d033d6cb47f4a80c58a35753646f5c3608a78/Sans/OTF/Japanese/NotoSansCJKjp-Regular.otf) · [许可证](https://raw.githubusercontent.com/notofonts/noto-cjk/523d033d6cb47f4a80c58a35753646f5c3608a78/LICENSE)

使用 FontTools 4.60.2 和 Python 3.9。输入为以下字符串的不同 Unicode 码点：

- 固定预览 artifact 十语 `catalog_i18n/*.json` 和 `i18n/*/*.json` 的 `names` 值，以及 `regions/*.json` 的 `nodes[].name` 和 `countries.json` 的 `countries[].name`。
- 固定 Geo SDK 提交 `d22f89578175e95e74b95640bf9d7410de140b0a` 下 `lib/src/ui/geo_picker_labels.dart` 的 `_defaults` 中 220 个文案。该源文件 SHA-256 为 `3b2174a64e48f18046b4d38fbf2b6f12b21c9508d6fbdc478c04bbf8355bbc3e`。

输入共 3,102 个码点。去除现有 NotoSansSC 两个字重均覆盖的码点和 Noto Sans Arabic full Regular 覆盖的码点，余 834 个。将余下码点升序排列成 `U+XXXX` 大写十六进制、空格分隔并以 LF 结束，SHA-256 为 `dbc4084fa9ab766379c7a06a4ab86a830d0aa560090e810d4384fc3dd14f1f49`。

FontTools 子集使用默认选项，另设置 `layout_features=['*']`、`name_IDs=[0,1,2,3,4,5,6,13,14,16,17]`、`name_languages=['*']`、`name_legacy=True` 和 `recalc_timestamp=False`，打开 TTFont 时也禁止重算时间戳。子集修改 name 表中的 family、unique ID、full name、PostScript name、typographic family，以及 CFF 名称为 IMBoyGeoCjk 系列，保留原作者与许可元数据。

派生 OTF 为 452,864 字节，SHA-256 为 `de2db367bb760dd19833a141a285b3ecad03df0abea773976ce4ac4d039ac53a`。按 SIL OFL 1.1 分发，许可证见 `OFL-Geo-CJK.txt`。

## Noto Sans Arabic full Regular

源字体为 Noto Sans Arabic v2.013，© 2022 The Noto Project Authors。官方 ZIP 中使用 `NotoSansArabic/full/ttf/NotoSansArabic-Regular.ttf` 原字节，资产路径与应用侧家族别名不改变字体内部名称。该 TTF 为 271,652 字节，SHA-256 为 `7ed3fe069312aceac454f17cf613a30f95271d6ed7ce58005ed4d016bd3823d7`。ZIP 的 SHA-256 为 `1301aceaea84c501cf2e6dcfb3182e2328c8eae5725817fcb239672bda7154f1`。按 SIL OFL 1.1 分发，许可证见 `OFL-Geo-Arabic.txt`。 [官方发布](https://github.com/notofonts/arabic/releases/tag/NotoSansArabic-v2.013)

两份字体分别与应用原有 Regular、Bold 字形表合并，均覆盖上述 3,102 个码点。本记录只证明固定输入的字形表覆盖。
