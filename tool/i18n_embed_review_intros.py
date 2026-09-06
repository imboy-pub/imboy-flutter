#!/usr/bin/env python3
"""一次性脚本：向 8 份母语审核包插入审核人母语导读。

插入点：首个 `### <locale>` 小节标题之前（即中文集成者元信息之后、表格之前）。
幂等：检测到「## <heading>」已存在则跳过该文件。
"""

from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

# locale -> (heading, intro paragraphs list)
INTROS = {
    "zh-Hant": (
        "## 致審核人",
        [
            "您好！IMBoy 是一款支援端對端加密、可自行架設伺服器的聊天 App。發布前我們正請各語言母語者協助校對介面文案，謝謝您幫忙！",
            "",
            "**做法**：逐行檢查下方表格的「zh-Hant 譯文」欄是否自然、準確（zh-CN 欄為簡體中文原文，僅供對照）：",
            "",
            "- 譯文沒問題 → 在第六欄「结论」（目前空著）寫 `✅`",
            "- 譯文需修改 → 在第六欄寫 `✗`，並在最後一欄「建议译文」（預設為 ✅）寫出您認可的完整譯文",
            "",
            "全部共 30 行，約 15–20 分鐘。專有名詞與品牌（Alipay、WeChat Pay、Huabei 等）依慣例保留拉丁原文，除非確有錯誤否則不必更動。",
            "",
            "完成後把本檔案直接回傳給邀請您的人即可，非常感謝！",
        ],
    ),
    "ja-JP": (
        "## レビュアーの方へ",
        [
            "こんにちは。IMBoy は暗号化対応のチャットアプリ（セルフホスト可能）です。公開前に、ネイティブスピーカーの方に UI 文言の最終チェックをお願いしています。ご協力ありがとうございます！",
            "",
            "**進め方**：下の表を1行ずつ確認し、「ja-JP 译文」の列（日本語訳）をチェックしてください（中国語の列は参考です。中国語が読めなくても大丈夫です）：",
            "",
            "- 訳で問題ない → 6列目（見出し「结论」、現在空欄）に `✅` を記入",
            "- 修正したい → 6列目に `✗` を記入し、最終列（見出し「建议译文」、初期値 ✅）に修正案を書く",
            "",
            "全30行、15〜20分ほどで終わります。固有名詞やブランド名（Alipay、WeChat Pay、Huabei など）は意図的にアルファベットのままにしています。明らかな誤りがない限り変更不要です。",
            "",
            "終わりましたら、このファイルをお声がけした方にお返しください。よろしくお願いします！",
        ],
    ),
    "ko-KR": (
        "## 검토자님께",
        [
            "안녕하세요! IMBoy는 종단간 암호화를 지원하는 셀프호스팅 채팅 앱입니다. 출시 전에 원어민 분들께 UI 문구를 최종 검토받고 있어요. 도움 주셔서 감사합니다!",
            "",
            "**진행 방법**: 아래 표를 한 줄씩 확인하며 「ko-KR 译文」 열(한국어 번역)을 점검해 주세요(중국어 열은 참고용이며, 중국어를 읽지 않으셔도 됩니다):",
            "",
            "- 번역에 문제없음 → 여섯 번째 열(제목 结论, 현재 비어 있음)에 `✅` 표기",
            "- 수정 필요 → 여섯 번째 열에 `✗` 표기 후, 마지막 열(제목 建议译文, 기본값 ✅)에 수정안을 작성",
            "",
            "총 30행, 약 15~20분 걸립니다. 고유명사와 브랜드명(Alipay, WeChat Pay, Huabei 등)은 의도적으로 라틴 문자로 유지하고 있습니다. 명백한 오류가 아니면 바꾸지 않으셔도 됩니다.",
            "",
            "다 보신 후 이 파일을 요청드린 분께 그대로 돌려주시면 됩니다. 감사합니다!",
        ],
    ),
    "de-DE": (
        "## An den Prüfer / die Prüferin",
        [
            "Hallo! IMBoy ist eine Chat-App mit Ende-zu-Ende-Verschlüsselung (selbst hostbar). Vor der Veröffentlichung lassen wir die Oberflächentexte von Muttersprachlern gegengelesen – danke, dass Du mithilfst!",
            "",
            "**So geht's**: Gehe die Tabelle unten Zeile für Zeile durch und prüfe die Spalte „de-DE 译文“ (deutsche Übersetzung; die chinesische Spalte ist nur die Referenz, Du musst kein Chinesisch können):",
            "",
            "- Übersetzung passt → schreibe `✅` in die sechste Spalte (Titel 结论, noch leer)",
            "- Übersetzung passt nicht → schreibe `✗` in die sechste Spalte und trage Deine Empfehlung in die letzte Spalte (Titel 建议译文, dort steht derzeit ✅) ein",
            "",
            "Insgesamt 30 Zeilen, ca. 15–20 Minuten. Eigennamen und Marken (Alipay, WeChat Pay, Huabei u. a.) bleiben bewusst lateinisch – bitte nur ändern, wenn wirklich falsch.",
            "",
            "Wenn Du fertig bist, schicke diese Datei einfach an die Person zurück, die Dich eingeladen hat. Vielen Dank!",
        ],
    ),
    "fr-FR": (
        "## Au relecteur / à la relectrice",
        [
            "Bonjour ! IMBoy est une application de messagerie chiffrée de bout en bout (auto-hébergeable). Avant la publication, nous faisons relire nos textes d'interface par des locuteurs natifs — merci pour votre aide !",
            "",
            "**Mode d'emploi** : parcourez le tableau ci-dessous ligne par ligne et vérifiez la colonne « fr-FR 译文 » (traduction française ; la colonne chinoise n'est qu'une référence, pas besoin de lire le chinois) :",
            "",
            "- traduction correcte → écrivez `✅` dans la sixième colonne (en-tête 结论, vide pour l'instant) ;",
            "- traduction à corriger → écrivez `✗` dans la sixième colonne et proposez votre version dans la dernière colonne (en-tête 建议译文, qui contient ✅ par défaut).",
            "",
            "30 lignes au total, 15 à 20 minutes environ. Les noms propres et marques (Alipay, WeChat Pay, Huabei…) restent volontairement en caractères latins — ne les modifiez que s'ils sont réellement erronés.",
            "",
            "Une fois terminé, renvoyez simplement ce fichier à la personne qui vous a contacté. Merci beaucoup !",
        ],
    ),
    "it-IT": (
        "## Al revisore / alla revisora",
        [
            "Ciao! IMBoy è un'app di messaggistica cifrata end-to-end (auto-ospitabile). Prima della pubblicazione facciamo rileggere i testi dell'interfaccia da madrelingua — grazie per la disponibilità!",
            "",
            "**Come procedere**: scorri la tabella qui sotto riga per riga e controlla la colonna «it-IT 译文» (traduzione italiana; la colonna cinese è solo di riferimento, non serve sapere il cinese):",
            "",
            "- traduzione corretta → scrivi `✅` nella sesta colonna (intestazione 结论, attualmente vuota);",
            "- traduzione da correggere → scrivi `✗` nella sesta colonna e scrivi la tua proposta nell'ultima colonna (intestazione 建议译文, contiene ✅ per impostazione predefinita).",
            "",
            "30 righe in totale, circa 15–20 minuti. Nomi propri e marchi (Alipay, WeChat Pay, Huabei…) restano volutamente in caratteri latini: modificali solo se davvero errati.",
            "",
            "Quando hai finito, rimanda semplicemente questo file alla persona che ti ha contattato. Grazie mille!",
        ],
    ),
    "ru-RU": (
        "## Рецензенту",
        [
            "Здравствуйте! IMBoy — это мессенджер со сквозным шифрованием (можно развернуть на своём сервере). Перед релизом мы просим носителей языка вычитать тексты интерфейса — спасибо, что помогаете!",
            "",
            "**Как проверять**: просмотрите таблицу ниже строка за строкой и оцените колонку «ru-RU 译文» (русский перевод; китайская колонка — лишь ориентир, читать по-китайски не нужно):",
            "",
            "- перевод хороший → поставьте `✅` в шестую колонку (заголовок 结论, сейчас пустая);",
            "- нужно исправить → поставьте `✗` в шестую колонку и напишите свой вариант в последней колонке (заголовок 建议译文, там сейчас стоит ✅).",
            "",
            "Всего 30 строк, примерно 15–20 минут. Имена собственные и бренды (Alipay, WeChat Pay, Huabei и т. д.) намеренно оставлены латиницей — меняйте их, только если они действительно неверны.",
            "",
            "Закончив, просто верните этот файл тому, кто вас пригласил. Большое спасибо!",
        ],
    ),
    "ar-SA": (
        "## إلى المراجع",
        [
            "مرحبًا! تطبيق IMBoy هو تطبيق محادثة بتشفير تام بين الطرفين (قابل للنشر على خادم خاص). قبل الإصدار نطلب من الناطقين الأصليين مراجعة نصوص الواجهة — شكرًا لمساعدتك!",
            "",
            "**طريقة المراجعة**: راجع الجدول أدناه سطرًا بسطر وتحقق من عمود «ar-SA 译文» (الترجمة العربية؛ العمود الصيني للمرجع فقط ولا تحتاج إلى قراءة الصينية):",
            "",
            "- الترجمة جيدة → اكتب `✅` في العمود السادس (العنوان 结论، وهو فارغ حاليًا)؛",
            "- تحتاج إلى تصحيح → اكتب `✗` في العمود السادس ثم اكتب صياغتك المقترحة في العمود الأخير (العنوان 建议译文، يحتوي حاليًا على ✅).",
            "",
            "الإجمالي 30 سطرًا، ويستغرق الأمر 15–20 دقيقة تقريبًا. أسماء الأعلام والعلامات التجارية (Alipay وWeChat Pay وHuabei وغيرها) تُركت بالحروف اللاتينية عمدًا — لا تغيّرها إلا إذا كانت خاطئة فعلًا.",
            "",
            "بعد الانتهاء، أعد هذا الملف كما هو إلى من دعاك إلى المراجعة. شكرًا جزيلًا!",
        ],
    ),
}


def main() -> None:
    for locale, (heading, lines) in INTROS.items():
        path = REPO / f"I18N_NATIVE_REVIEW_{locale}.md"
        text = path.read_text(encoding="utf-8")
        if heading in text:
            print(f"SKIP {path.name}: intro already present")
            continue
        out = []
        inserted = False
        for line in text.split("\n"):
            if not inserted and line.startswith("### "):
                out.append("\n".join([heading, *lines]))
                out.append("")  # 与小节标题之间保留一个空行
                inserted = True
            out.append(line)
        if not inserted:
            raise SystemExit(f"FATAL {path.name}: no '### ' section header found")
        path.write_text("\n".join(out), encoding="utf-8")
        print(f"OK   {path.name}: intro embedded ({len(lines) + 1} lines)")


if __name__ == "__main__":
    main()
