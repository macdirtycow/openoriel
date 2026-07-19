import Foundation

/// Shared multilingual catalog for Chrome Web Store + Firefox Add-ons bridges.
/// Detects localized install CTAs and emits Oriel labels / tips in the page language.
enum StoreBridgeI18n {
    /// Inject at document-start (page world), before store bridges.
    static let catalogSource = #"""
    (function () {
      if (window.__orielStoreI18n) return;

      var STRINGS = {
        en: {
          add: 'Add to Oriel',
          addTheme: 'Add theme to Oriel',
          installing: 'Installing…',
          installed: 'Installed in Oriel',
          remove: 'Remove from Oriel',
          tipChrome: 'Oriel can install this extension on iPhone and iPad — tap Add to Oriel.',
          tipFirefox: 'Oriel can install this Firefox add-on on iPhone and iPad — tap Add to Oriel.'
        },
        nl: {
          add: 'Toevoegen aan Oriel',
          addTheme: 'Thema toevoegen aan Oriel',
          installing: 'Bezig met installeren…',
          installed: 'Geïnstalleerd in Oriel',
          remove: 'Verwijderen uit Oriel',
          tipChrome: 'Oriel kan deze extensie op iPhone en iPad installeren — tik op Toevoegen aan Oriel.',
          tipFirefox: 'Oriel kan deze Firefox-add-on op iPhone en iPad installeren — tik op Toevoegen aan Oriel.'
        },
        de: {
          add: 'Zu Oriel hinzufügen',
          addTheme: 'Theme zu Oriel hinzufügen',
          installing: 'Wird installiert…',
          installed: 'In Oriel installiert',
          remove: 'Aus Oriel entfernen',
          tipChrome: 'Oriel kann diese Erweiterung auf iPhone und iPad installieren — tippe auf Zu Oriel hinzufügen.',
          tipFirefox: 'Oriel kann dieses Firefox-Add-on auf iPhone und iPad installieren — tippe auf Zu Oriel hinzufügen.'
        },
        fr: {
          add: 'Ajouter à Oriel',
          addTheme: 'Ajouter le thème à Oriel',
          installing: 'Installation…',
          installed: 'Installé dans Oriel',
          remove: 'Supprimer d\'Oriel',
          tipChrome: 'Oriel peut installer cette extension sur iPhone et iPad — appuyez sur Ajouter à Oriel.',
          tipFirefox: 'Oriel peut installer ce module Firefox sur iPhone et iPad — appuyez sur Ajouter à Oriel.'
        },
        es: {
          add: 'Añadir a Oriel',
          addTheme: 'Añadir tema a Oriel',
          installing: 'Instalando…',
          installed: 'Instalado en Oriel',
          remove: 'Quitar de Oriel',
          tipChrome: 'Oriel puede instalar esta extensión en iPhone y iPad: toca Añadir a Oriel.',
          tipFirefox: 'Oriel puede instalar este complemento de Firefox en iPhone y iPad: toca Añadir a Oriel.'
        },
        'es-419': {
          add: 'Agregar a Oriel',
          addTheme: 'Agregar tema a Oriel',
          installing: 'Instalando…',
          installed: 'Instalado en Oriel',
          remove: 'Quitar de Oriel',
          tipChrome: 'Oriel puede instalar esta extensión en iPhone y iPad: toca Agregar a Oriel.',
          tipFirefox: 'Oriel puede instalar este complemento de Firefox en iPhone y iPad: toca Agregar a Oriel.'
        },
        it: {
          add: 'Aggiungi a Oriel',
          addTheme: 'Aggiungi tema a Oriel',
          installing: 'Installazione…',
          installed: 'Installato in Oriel',
          remove: 'Rimuovi da Oriel',
          tipChrome: 'Oriel può installare questa estensione su iPhone e iPad — tocca Aggiungi a Oriel.',
          tipFirefox: 'Oriel può installare questo componente aggiuntivo Firefox su iPhone e iPad — tocca Aggiungi a Oriel.'
        },
        pt: {
          add: 'Adicionar ao Oriel',
          addTheme: 'Adicionar tema ao Oriel',
          installing: 'A instalar…',
          installed: 'Instalado no Oriel',
          remove: 'Remover do Oriel',
          tipChrome: 'O Oriel pode instalar esta extensão no iPhone e iPad — toque em Adicionar ao Oriel.',
          tipFirefox: 'O Oriel pode instalar este extra do Firefox no iPhone e iPad — toque em Adicionar ao Oriel.'
        },
        'pt-br': {
          add: 'Adicionar ao Oriel',
          addTheme: 'Adicionar tema ao Oriel',
          installing: 'Instalando…',
          installed: 'Instalado no Oriel',
          remove: 'Remover do Oriel',
          tipChrome: 'O Oriel pode instalar esta extensão no iPhone e iPad — toque em Adicionar ao Oriel.',
          tipFirefox: 'O Oriel pode instalar esta extensão do Firefox no iPhone e iPad — toque em Adicionar ao Oriel.'
        },
        pl: {
          add: 'Dodaj do Oriel',
          addTheme: 'Dodaj motyw do Oriel',
          installing: 'Instalowanie…',
          installed: 'Zainstalowano w Oriel',
          remove: 'Usuń z Oriel',
          tipChrome: 'Oriel może zainstalować to rozszerzenie na iPhonie i iPadzie — kliknij Dodaj do Oriel.',
          tipFirefox: 'Oriel może zainstalować ten dodatek Firefox na iPhonie i iPadzie — kliknij Dodaj do Oriel.'
        },
        ru: {
          add: 'Добавить в Oriel',
          addTheme: 'Добавить тему в Oriel',
          installing: 'Установка…',
          installed: 'Установлено в Oriel',
          remove: 'Удалить из Oriel',
          tipChrome: 'Oriel может установить это расширение на iPhone и iPad — нажмите «Добавить в Oriel».',
          tipFirefox: 'Oriel может установить это дополнение Firefox на iPhone и iPad — нажмите «Добавить в Oriel».'
        },
        uk: {
          add: 'Додати до Oriel',
          addTheme: 'Додати тему до Oriel',
          installing: 'Встановлення…',
          installed: 'Встановлено в Oriel',
          remove: 'Видалити з Oriel',
          tipChrome: 'Oriel може встановити це розширення на iPhone та iPad — натисніть «Додати до Oriel».',
          tipFirefox: 'Oriel може встановити цей додаток Firefox на iPhone та iPad — натисніть «Додати до Oriel».'
        },
        cs: {
          add: 'Přidat do Oriel',
          addTheme: 'Přidat motiv do Oriel',
          installing: 'Instalace…',
          installed: 'Nainstalováno v Oriel',
          remove: 'Odebrat z Oriel',
          tipChrome: 'Oriel může tuto rozšíření nainstalovat na iPhone a iPad — klepněte na Přidat do Oriel.',
          tipFirefox: 'Oriel může tento doplněk Firefox nainstalovat na iPhone a iPad — klepněte na Přidat do Oriel.'
        },
        sk: {
          add: 'Pridať do Oriel',
          addTheme: 'Pridať motív do Oriel',
          installing: 'Inštalácia…',
          installed: 'Nainštalované v Oriel',
          remove: 'Odstrániť z Oriel',
          tipChrome: 'Oriel môže toto rozšírenie nainštalovať na iPhone a iPad — klepnite na Pridať do Oriel.',
          tipFirefox: 'Oriel môže tento doplnok Firefox nainštalovať na iPhone a iPad — klepnite na Pridať do Oriel.'
        },
        hu: {
          add: 'Hozzáadás az Orielhez',
          addTheme: 'Téma hozzáadása az Orielhez',
          installing: 'Telepítés…',
          installed: 'Telepítve az Orielben',
          remove: 'Eltávolítás Orielből',
          tipChrome: 'Az Oriel telepítheti ezt a bővítményt iPhone-ra és iPadre — koppints a Hozzáadás az Orielhez gombra.',
          tipFirefox: 'Az Oriel telepítheti ezt a Firefox-kiegészítőt iPhone-ra és iPadre — koppints a Hozzáadás az Orielhez gombra.'
        },
        ro: {
          add: 'Adaugă în Oriel',
          addTheme: 'Adaugă tema în Oriel',
          installing: 'Se instalează…',
          installed: 'Instalat în Oriel',
          remove: 'Elimină din Oriel',
          tipChrome: 'Oriel poate instala această extensie pe iPhone și iPad — atinge Adaugă în Oriel.',
          tipFirefox: 'Oriel poate instala acest supliment Firefox pe iPhone și iPad — atinge Adaugă în Oriel.'
        },
        sv: {
          add: 'Lägg till i Oriel',
          addTheme: 'Lägg till tema i Oriel',
          installing: 'Installerar…',
          installed: 'Installerad i Oriel',
          remove: 'Ta bort från Oriel',
          tipChrome: 'Oriel kan installera detta tillägg på iPhone och iPad — tryck på Lägg till i Oriel.',
          tipFirefox: 'Oriel kan installera detta Firefox-tillägg på iPhone och iPad — tryck på Lägg till i Oriel.'
        },
        da: {
          add: 'Føj til Oriel',
          addTheme: 'Føj tema til Oriel',
          installing: 'Installerer…',
          installed: 'Installeret i Oriel',
          remove: 'Fjern fra Oriel',
          tipChrome: 'Oriel kan installere denne udvidelse på iPhone og iPad — tryk på Føj til Oriel.',
          tipFirefox: 'Oriel kan installere denne Firefox-tilføjelse på iPhone og iPad — tryk på Føj til Oriel.'
        },
        nb: {
          add: 'Legg til i Oriel',
          addTheme: 'Legg til tema i Oriel',
          installing: 'Installerer…',
          installed: 'Installert i Oriel',
          remove: 'Fjern fra Oriel',
          tipChrome: 'Oriel kan installere denne utvidelsen på iPhone og iPad — trykk på Legg til i Oriel.',
          tipFirefox: 'Oriel kan installere dette Firefox-tillegget på iPhone og iPad — trykk på Legg til i Oriel.'
        },
        fi: {
          add: 'Lisää Orieliin',
          addTheme: 'Lisää teema Orieliin',
          installing: 'Asennetaan…',
          installed: 'Asennettu Orieliin',
          remove: 'Poista Orielista',
          tipChrome: 'Oriel voi asentaa tämän laajennuksen iPhoneen ja iPadiin — napauta Lisää Orieliin.',
          tipFirefox: 'Oriel voi asentaa tämän Firefox-lisäosan iPhoneen ja iPadiin — napauta Lisää Orieliin.'
        },
        el: {
          add: 'Προσθήκη στο Oriel',
          addTheme: 'Προσθήκη θέματος στο Oriel',
          installing: 'Εγκατάσταση…',
          installed: 'Εγκαταστάθηκε στο Oriel',
          remove: 'Κατάργηση από το Oriel',
          tipChrome: 'Το Oriel μπορεί να εγκαταστήσει αυτήν την επέκταση σε iPhone και iPad — πατήστε Προσθήκη στο Oriel.',
          tipFirefox: 'Το Oriel μπορεί να εγκαταστήσει αυτό το πρόσθετο Firefox σε iPhone και iPad — πατήστε Προσθήκη στο Oriel.'
        },
        tr: {
          add: "Oriel'e ekle",
          addTheme: "Oriel'e tema ekle",
          installing: 'Yükleniyor…',
          installed: "Oriel'e yüklendi",
          remove: 'Oriel\'den kaldır',
          tipChrome: "Oriel bu uzantıyı iPhone ve iPad'e yükleyebilir — Oriel'e ekle'ye dokunun.",
          tipFirefox: "Oriel bu Firefox eklentisini iPhone ve iPad'e yükleyebilir — Oriel'e ekle'ye dokunun."
        },
        ar: {
          add: 'إضافة إلى Oriel',
          addTheme: 'إضافة السمة إلى Oriel',
          installing: 'جارٍ التثبيت…',
          installed: 'مثبّت في Oriel',
          remove: 'إزالة من Oriel',
          tipChrome: 'يمكن لـ Oriel تثبيت هذا الامتداد على iPhone وiPad — انقر إضافة إلى Oriel.',
          tipFirefox: 'يمكن لـ Oriel تثبيت إضافة Firefox هذه على iPhone وiPad — انقر إضافة إلى Oriel.'
        },
        he: {
          add: 'הוסף ל-Oriel',
          addTheme: 'הוסף ערכת נושא ל-Oriel',
          installing: 'מתקין…',
          installed: 'מותקן ב-Oriel',
          remove: 'הסר מ-Oriel',
          tipChrome: 'Oriel יכול להתקין את התוסף הזה ב-iPhone וב-iPad — הקש על הוסף ל-Oriel.',
          tipFirefox: 'Oriel יכול להתקין את תוסף Firefox הזה ב-iPhone וב-iPad — הקש על הוסף ל-Oriel.'
        },
        hi: {
          add: 'Oriel में जोड़ें',
          addTheme: 'Oriel में थीम जोड़ें',
          installing: 'इंस्टॉल हो रहा है…',
          installed: 'Oriel में इंस्टॉल किया गया',
          remove: 'Oriel से हटाएँ',
          tipChrome: 'Oriel इस एक्सटेंशन को iPhone और iPad पर इंस्टॉल कर सकता है — Oriel में जोड़ें पर टैप करें।',
          tipFirefox: 'Oriel इस Firefox ऐड-ऑन को iPhone और iPad पर इंस्टॉल कर सकता है — Oriel में जोड़ें पर टैप करें।'
        },
        th: {
          add: 'เพิ่มไปยัง Oriel',
          addTheme: 'เพิ่มธีมไปยัง Oriel',
          installing: 'กำลังติดตั้ง…',
          installed: 'ติดตั้งใน Oriel แล้ว',
          remove: 'นำออกจาก Oriel',
          tipChrome: 'Oriel สามารถติดตั้งส่วนขยายนี้บน iPhone และ iPad ได้ — แตะ เพิ่มไปยัง Oriel',
          tipFirefox: 'Oriel สามารถติดตั้งส่วนเสริม Firefox นี้บน iPhone และ iPad ได้ — แตะ เพิ่มไปยัง Oriel'
        },
        vi: {
          add: 'Thêm vào Oriel',
          addTheme: 'Thêm giao diện vào Oriel',
          installing: 'Đang cài đặt…',
          installed: 'Đã cài trong Oriel',
          remove: 'Gỡ khỏi Oriel',
          tipChrome: 'Oriel có thể cài tiện ích này trên iPhone và iPad — nhấn Thêm vào Oriel.',
          tipFirefox: 'Oriel có thể cài tiện ích Firefox này trên iPhone và iPad — nhấn Thêm vào Oriel.'
        },
        id: {
          add: 'Tambahkan ke Oriel',
          addTheme: 'Tambahkan tema ke Oriel',
          installing: 'Menginstal…',
          installed: 'Terinstal di Oriel',
          remove: 'Hapus dari Oriel',
          tipChrome: 'Oriel dapat menginstal ekstensi ini di iPhone dan iPad — ketuk Tambahkan ke Oriel.',
          tipFirefox: 'Oriel dapat menginstal pengaya Firefox ini di iPhone dan iPad — ketuk Tambahkan ke Oriel.'
        },
        ms: {
          add: 'Tambah ke Oriel',
          addTheme: 'Tambah tema ke Oriel',
          installing: 'Memasang…',
          installed: 'Dipasang dalam Oriel',
          remove: 'Alih keluar dari Oriel',
          tipChrome: 'Oriel boleh memasang sambungan ini pada iPhone dan iPad — ketik Tambah ke Oriel.',
          tipFirefox: 'Oriel boleh memasang tambahan Firefox ini pada iPhone dan iPad — ketik Tambah ke Oriel.'
        },
        ja: {
          add: 'Oriel に追加',
          addTheme: 'テーマを Oriel に追加',
          installing: 'インストール中…',
          installed: 'Oriel にインストール済み',
          remove: 'Oriel から削除',
          tipChrome: 'Oriel はこの拡張機能を iPhone / iPad にインストールできます —「Oriel に追加」をタップ。',
          tipFirefox: 'Oriel はこの Firefox アドオンを iPhone / iPad にインストールできます —「Oriel に追加」をタップ。'
        },
        ko: {
          add: 'Oriel에 추가',
          addTheme: 'Oriel에 테마 추가',
          installing: '설치 중…',
          installed: 'Oriel에 설치됨',
          remove: 'Oriel에서 삭제',
          tipChrome: 'Oriel은 이 확장 프로그램을 iPhone 및 iPad에 설치할 수 있습니다 — Oriel에 추가를 탭하세요.',
          tipFirefox: 'Oriel은 이 Firefox 부가 기능을 iPhone 및 iPad에 설치할 수 있습니다 — Oriel에 추가를 탭하세요.'
        },
        'zh-cn': {
          add: '添加至 Oriel',
          addTheme: '将主题添加至 Oriel',
          installing: '正在安装…',
          installed: '已安装到 Oriel',
          remove: '从 Oriel 中移除',
          tipChrome: 'Oriel 可在 iPhone 和 iPad 上安装此扩展 — 点按“添加至 Oriel”。',
          tipFirefox: 'Oriel 可在 iPhone 和 iPad 上安装此 Firefox 附加组件 — 点按“添加至 Oriel”。'
        },
        'zh-tw': {
          add: '加到 Oriel',
          addTheme: '將主題加到 Oriel',
          installing: '正在安裝…',
          installed: '已安裝到 Oriel',
          remove: '從 Oriel 移除',
          tipChrome: 'Oriel 可在 iPhone 和 iPad 上安裝此擴充功能 — 點一下「加到 Oriel」。',
          tipFirefox: 'Oriel 可在 iPhone 和 iPad 上安裝此 Firefox 附加元件 — 點一下「加到 Oriel」。'
        },
        ca: {
          add: 'Afegeix a Oriel',
          addTheme: 'Afegeix el tema a Oriel',
          installing: 'S’està instal·lant…',
          installed: 'Instal·lat a Oriel',
          remove: 'Suprimeix d\'Oriel',
          tipChrome: 'Oriel pot instal·lar aquesta extensió a l’iPhone i l’iPad — toca Afegeix a Oriel.',
          tipFirefox: 'Oriel pot instal·lar aquest complement de Firefox a l’iPhone i l’iPad — toca Afegeix a Oriel.'
        },
        hr: {
          add: 'Dodaj u Oriel',
          addTheme: 'Dodaj temu u Oriel',
          installing: 'Instaliranje…',
          installed: 'Instalirano u Oriel',
          remove: 'Ukloni iz Oriel',
          tipChrome: 'Oriel može instalirati ovo proširenje na iPhone i iPad — dodirnite Dodaj u Oriel.',
          tipFirefox: 'Oriel može instalirati ovaj Firefox dodatak na iPhone i iPad — dodirnite Dodaj u Oriel.'
        },
        bg: {
          add: 'Добавяне към Oriel',
          addTheme: 'Добавяне на тема към Oriel',
          installing: 'Инсталиране…',
          installed: 'Инсталирано в Oriel',
          remove: 'Премахни от Oriel',
          tipChrome: 'Oriel може да инсталира това разширение на iPhone и iPad — докоснете Добавяне към Oriel.',
          tipFirefox: 'Oriel може да инсталира тази добавка за Firefox на iPhone и iPad — докоснете Добавяне към Oriel.'
        },
        lt: {
          add: 'Pridėti prie Oriel',
          addTheme: 'Pridėti temą prie Oriel',
          installing: 'Diegiama…',
          installed: 'Įdiegta „Oriel“',
          remove: 'Pašalinti iš Oriel',
          tipChrome: '„Oriel“ gali įdiegti šį plėtinį iPhone ir iPad — bakstelėkite Pridėti prie Oriel.',
          tipFirefox: '„Oriel“ gali įdiegti šį Firefox priedą iPhone ir iPad — bakstelėkite Pridėti prie Oriel.'
        },
        lv: {
          add: 'Pievienot Oriel',
          addTheme: 'Pievienot tēmu Oriel',
          installing: 'Notiek instalēšana…',
          installed: 'Instalēts Oriel',
          remove: 'Noņemt no Oriel',
          tipChrome: 'Oriel var instalēt šo paplašinājumu iPhone un iPad — pieskarieties Pievienot Oriel.',
          tipFirefox: 'Oriel var instalēt šo Firefox papildinājumu iPhone un iPad — pieskarieties Pievienot Oriel.'
        },
        et: {
          add: 'Lisa Orielisse',
          addTheme: 'Lisa teema Orielisse',
          installing: 'Installimine…',
          installed: 'Installitud Orielisse',
          remove: 'Eemalda Orielist',
          tipChrome: 'Oriel saab selle laiendi iPhone’i ja iPadi installida — puuduta Lisa Orielisse.',
          tipFirefox: 'Oriel saab selle Firefoxi lisandmooduli iPhone’i ja iPadi installida — puuduta Lisa Orielisse.'
        },
        sl: {
          add: 'Dodaj v Oriel',
          addTheme: 'Dodaj temo v Oriel',
          installing: 'Nameščanje…',
          installed: 'Nameščeno v Oriel',
          remove: 'Odstrani iz Oriel',
          tipChrome: 'Oriel lahko to razširitev namesti na iPhone in iPad — tapnite Dodaj v Oriel.',
          tipFirefox: 'Oriel lahko ta Firefoxov dodatek namesti na iPhone in iPad — tapnite Dodaj v Oriel.'
        },
        ga: {
          add: 'Cuir le Oriel',
          addTheme: 'Cuir téama le Oriel',
          installing: 'Á shuiteáil…',
          installed: 'Suiteáilte in Oriel',
          remove: 'Bain as Oriel',
          tipChrome: 'Is féidir le Oriel an eisínteacht seo a shuiteáil ar iPhone agus iPad — tapáil Cuir le Oriel.',
          tipFirefox: 'Is féidir le Oriel an breiseán Firefox seo a shuiteáil ar iPhone agus iPad — tapáil Cuir le Oriel.'
        },
        eu: {
          add: 'Gehitu Oriel-era',
          addTheme: 'Gehitu gaia Oriel-era',
          installing: 'Instalatzen…',
          installed: 'Oriel-en instalatuta',
          remove: 'Kendu Oriel-etik',
          tipChrome: 'Oriel-ek luzapen hau iPhone eta iPad-ean instala dezake — sakatu Gehitu Oriel-era.',
          tipFirefox: 'Oriel-ek Firefox gehigarri hau iPhone eta iPad-ean instala dezake — sakatu Gehitu Oriel-era.'
        },
        gl: {
          add: 'Engadir a Oriel',
          addTheme: 'Engadir tema a Oriel',
          installing: 'Instalando…',
          installed: 'Instalado en Oriel',
          remove: 'Quitar de Oriel',
          tipChrome: 'Oriel pode instalar esta extensión no iPhone e no iPad — toca Engadir a Oriel.',
          tipFirefox: 'Oriel pode instalar este complemento de Firefox no iPhone e no iPad — toca Engadir a Oriel.'
        },
        af: {
          add: 'Voeg by Oriel',
          addTheme: 'Voeg tema by Oriel',
          installing: 'Installeer…',
          installed: 'In Oriel geïnstalleer',
          remove: 'Verwyder uit Oriel',
          tipChrome: 'Oriel kan hierdie uitbreiding op iPhone en iPad installeer — tik Voeg by Oriel.',
          tipFirefox: 'Oriel kan hierdie Firefox-byvoeging op iPhone en iPad installeer — tik Voeg by Oriel.'
        },
        sq: {
          add: 'Shto te Oriel',
          addTheme: 'Shto temën te Oriel',
          installing: 'Duke instaluar…',
          installed: 'E instaluar në Oriel',
          remove: 'Hiq nga Oriel',
          tipChrome: 'Oriel mund ta instalojë këtë zgjerim në iPhone dhe iPad — trokit Shto te Oriel.',
          tipFirefox: 'Oriel mund ta instalojë këtë shtesë Firefox në iPhone dhe iPad — trokit Shto te Oriel.'
        },
        mk: {
          add: 'Додај во Oriel',
          addTheme: 'Додај тема во Oriel',
          installing: 'Се инсталира…',
          installed: 'Инсталирано во Oriel',
          remove: 'Отстрани од Oriel',
          tipChrome: 'Oriel може да го инсталира ова проширување на iPhone и iPad — допрете Додај во Oriel.',
          tipFirefox: 'Oriel може да го инсталира овој додаток за Firefox на iPhone и iPad — допрете Додај во Oriel.'
        },
        be: {
          add: 'Дадаць у Oriel',
          addTheme: 'Дадаць тэму ў Oriel',
          installing: 'Усталёўка…',
          installed: 'Усталявана ў Oriel',
          remove: 'Выдаліць з Oriel',
          tipChrome: 'Oriel можа ўсталяваць гэтае пашырэнне на iPhone і iPad — націсніце «Дадаць у Oriel».',
          tipFirefox: 'Oriel можа ўсталяваць гэты дадатак Firefox на iPhone і iPad — націсніце «Дадаць у Oriel».'
        },
        ka: {
          add: 'Oriel-ში დამატება',
          addTheme: 'თემის დამატება Oriel-ში',
          installing: 'მიმდინარეობს დაყენება…',
          installed: 'დაყენებულია Oriel-ში',
          remove: 'Oriel-დან ამოშლა',
          tipChrome: 'Oriel-ს შეუძლია ამ გაფართოების დაყენება iPhone-სა და iPad-ზე — შეეხეთ „Oriel-ში დამატება“.',
          tipFirefox: 'Oriel-ს შეუძლია ამ Firefox დამატების დაყენება iPhone-სა და iPad-ზე — შეეხეთ „Oriel-ში დამატება“.'
        },
        hy: {
          add: 'Ավելացնել Oriel',
          addTheme: 'Ավելացնել թեմա Oriel',
          installing: 'Տեղադրվում է…',
          installed: 'Տեղադրված է Oriel-ում',
          remove: 'Հեռացնել Oriel-ից',
          tipChrome: 'Oriel-ը կարող է տեղադրել այս ընդլայնումը iPhone-ում և iPad-ում — հպեք Ավելացնել Oriel։',
          tipFirefox: 'Oriel-ը կարող է տեղադրել այս Firefox հավելումը iPhone-ում և iPad-ում — հպեք Ավելացնել Oriel։'
        },
        az: {
          add: 'Oriel-ə əlavə et',
          addTheme: 'Oriel-ə tema əlavə et',
          installing: 'Quraşdırılır…',
          installed: 'Oriel-də quraşdırılıb',
          remove: 'Oriel-dən sil',
          tipChrome: 'Oriel bu genişləndirməni iPhone və iPad-ə quraşdıra bilər — Oriel-ə əlavə et düyməsinə toxunun.',
          tipFirefox: 'Oriel bu Firefox əlavəsini iPhone və iPad-ə quraşdıra bilər — Oriel-ə əlavə et düyməsinə toxunun.'
        },
        kk: {
          add: 'Oriel-ге қосу',
          addTheme: 'Oriel-ге тема қосу',
          installing: 'Орнатылуда…',
          installed: 'Oriel-де орнатылған',
          remove: 'Oriel-ден жою',
          tipChrome: 'Oriel бұл кеңейтімді iPhone және iPad құрылғысына орната алады — «Oriel-ге қосу» түймесін түртіңіз.',
          tipFirefox: 'Oriel бұл Firefox қосымшасын iPhone және iPad құрылғысына орната алады — «Oriel-ге қосу» түймесін түртіңіз.'
        },
        uz: {
          add: "Orielga qo'shish",
          addTheme: "Orielga mavzu qo'shish",
          installing: "O'rnatilmoqda…",
          installed: "Orielda o'rnatilgan",
          remove: 'Orieldan o\'chirish',
          tipChrome: "Oriel ushbu kengaytmani iPhone va iPadga o'rnatishi mumkin — Orielga qo'shish tugmasini bosing.",
          tipFirefox: "Oriel ushbu Firefox qo'shimchasini iPhone va iPadga o'rnatishi mumkin — Orielga qo'shish tugmasini bosing."
        },
        bn: {
          add: 'Oriel-এ যোগ করুন',
          addTheme: 'Oriel-এ থিম যোগ করুন',
          installing: 'ইনস্টল হচ্ছে…',
          installed: 'Oriel-এ ইনস্টল করা হয়েছে',
          remove: 'Oriel থেকে সরান',
          tipChrome: 'Oriel এই এক্সটেনশনটি iPhone ও iPad-এ ইনস্টল করতে পারে — Oriel-এ যোগ করুন ট্যাপ করুন।',
          tipFirefox: 'Oriel এই Firefox অ্যাড-অনটি iPhone ও iPad-এ ইনস্টল করতে পারে — Oriel-এ যোগ করুন ট্যাপ করুন।'
        },
        ta: {
          add: 'Oriel இல் சேர்',
          addTheme: 'Oriel இல் தீம் சேர்',
          installing: 'நிறுவுகிறது…',
          installed: 'Oriel இல் நிறுவப்பட்டது',
          remove: 'Oriel இலிருந்து அகற்று',
          tipChrome: 'Oriel இந்த நீட்டிப்பை iPhone மற்றும் iPad இல் நிறுவலாம் — Oriel இல் சேர் என்பதைத் தட்டவும்.',
          tipFirefox: 'Oriel இந்த Firefox துணை நிரலை iPhone மற்றும் iPad இல் நிறுவலாம் — Oriel இல் சேர் என்பதைத் தட்டவும்.'
        },
        te: {
          add: 'Orielకి జోడించు',
          addTheme: 'Orielకి థీమ్ జోడించు',
          installing: 'Installing…',
          installed: 'Installed in Oriel',
          remove: 'Remove from Oriel',
          tipChrome: 'Oriel can install this extension on iPhone and iPad — tap Add to Oriel.',
          tipFirefox: 'Oriel can install this Firefox add-on on iPhone and iPad — tap Add to Oriel.'
        },
        ml: {
          add: 'Add to Oriel',
          addTheme: 'Add theme to Oriel',
          installing: 'Installing…',
          installed: 'Installed in Oriel',
          remove: 'Remove from Oriel',
          tipChrome: 'Oriel can install this extension on iPhone and iPad — tap Add to Oriel.',
          tipFirefox: 'Oriel can install this Firefox add-on on iPhone and iPad — tap Add to Oriel.'
        },
        kn: {
          add: 'Add to Oriel',
          addTheme: 'Add theme to Oriel',
          installing: 'Installing…',
          installed: 'Installed in Oriel',
          remove: 'Remove from Oriel',
          tipChrome: 'Oriel can install this extension on iPhone and iPad — tap Add to Oriel.',
          tipFirefox: 'Oriel can install this Firefox add-on on iPhone and iPad — tap Add to Oriel.'
        },
        gu: {
          add: 'Add to Oriel',
          addTheme: 'Add theme to Oriel',
          installing: 'Installing…',
          installed: 'Installed in Oriel',
          remove: 'Remove from Oriel',
          tipChrome: 'Oriel can install this extension on iPhone and iPad — tap Add to Oriel.',
          tipFirefox: 'Oriel can install this Firefox add-on on iPhone and iPad — tap Add to Oriel.'
        },
        pa: {
          add: 'Add to Oriel',
          addTheme: 'Add theme to Oriel',
          installing: 'Installing…',
          installed: 'Installed in Oriel',
          remove: 'Remove from Oriel',
          tipChrome: 'Oriel can install this extension on iPhone and iPad — tap Add to Oriel.',
          tipFirefox: 'Oriel can install this Firefox add-on on iPhone and iPad — tap Add to Oriel.'
        },
        si: {
          add: 'Add to Oriel',
          addTheme: 'Add theme to Oriel',
          installing: 'Installing…',
          installed: 'Installed in Oriel',
          remove: 'Remove from Oriel',
          tipChrome: 'Oriel can install this extension on iPhone and iPad — tap Add to Oriel.',
          tipFirefox: 'Oriel can install this Firefox add-on on iPhone and iPad — tap Add to Oriel.'
        },
        my: {
          add: 'Add to Oriel',
          addTheme: 'Add theme to Oriel',
          installing: 'Installing…',
          installed: 'Installed in Oriel',
          remove: 'Remove from Oriel',
          tipChrome: 'Oriel can install this extension on iPhone and iPad — tap Add to Oriel.',
          tipFirefox: 'Oriel can install this Firefox add-on on iPhone and iPad — tap Add to Oriel.'
        },
        km: {
          add: 'Add to Oriel',
          addTheme: 'Add theme to Oriel',
          installing: 'Installing…',
          installed: 'Installed in Oriel',
          remove: 'Remove from Oriel',
          tipChrome: 'Oriel can install this extension on iPhone and iPad — tap Add to Oriel.',
          tipFirefox: 'Oriel can install this Firefox add-on on iPhone and iPad — tap Add to Oriel.'
        },
        lo: {
          add: 'Add to Oriel',
          addTheme: 'Add theme to Oriel',
          installing: 'Installing…',
          installed: 'Installed in Oriel',
          remove: 'Remove from Oriel',
          tipChrome: 'Oriel can install this extension on iPhone and iPad — tap Add to Oriel.',
          tipFirefox: 'Oriel can install this Firefox add-on on iPhone and iPad — tap Add to Oriel.'
        },
        fil: {
          add: 'Idagdag sa Oriel',
          addTheme: 'Idagdag ang tema sa Oriel',
          installing: 'Ini-install…',
          installed: 'Naka-install sa Oriel',
          remove: 'Alisin sa Oriel',
          tipChrome: 'Maaaring i-install ng Oriel ang extension na ito sa iPhone at iPad — i-tap ang Idagdag sa Oriel.',
          tipFirefox: 'Maaaring i-install ng Oriel ang Firefox add-on na ito sa iPhone at iPad — i-tap ang Idagdag sa Oriel.'
        },
        sw: {
          add: 'Ongeza kwa Oriel',
          addTheme: 'Ongeza tema kwa Oriel',
          installing: 'Inasakinisha…',
          installed: 'Imesakinishwa katika Oriel',
          remove: 'Ondoa kutoka Oriel',
          tipChrome: 'Oriel inaweza kusakinisha kiendelezi hiki kwenye iPhone na iPad — gusa Ongeza kwa Oriel.',
          tipFirefox: 'Oriel inaweza kusakinisha kiendelezi hiki cha Firefox kwenye iPhone na iPad — gusa Ongeza kwa Oriel.'
        },
        am: {
          add: 'Add to Oriel',
          addTheme: 'Add theme to Oriel',
          installing: 'Installing…',
          installed: 'Installed in Oriel',
          remove: 'Remove from Oriel',
          tipChrome: 'Oriel can install this extension on iPhone and iPad — tap Add to Oriel.',
          tipFirefox: 'Oriel can install this Firefox add-on on iPhone and iPad — tap Add to Oriel.'
        },
        is: {
          add: 'Bæta við Oriel',
          addTheme: 'Bæta þema við Oriel',
          installing: 'Setur upp…',
          installed: 'Uppsett í Oriel',
          remove: 'Fjarlægja úr Oriel',
          tipChrome: 'Oriel getur sett þessa viðbót upp á iPhone og iPad — ýttu á Bæta við Oriel.',
          tipFirefox: 'Oriel getur sett þessa Firefox-viðbót upp á iPhone og iPad — ýttu á Bæta við Oriel.'
        },
        mt: {
          add: "Żid ma' Oriel",
          addTheme: "Żid tema ma' Oriel",
          installing: 'Qed jinstalla…',
          installed: "Installat f'Oriel",
          remove: 'Neħħi minn Oriel',
          tipChrome: "Oriel jista' jinstalla din l-estensjoni fuq iPhone u iPad — agħfas Żid ma' Oriel.",
          tipFirefox: "Oriel jista' jinstalla dan il-add-on ta' Firefox fuq iPhone u iPad — agħfas Żid ma' Oriel."
        },
        cy: {
          add: 'Ychwanegu at Oriel',
          addTheme: 'Ychwanegu thema at Oriel',
          installing: 'Yn gosod…',
          installed: "Wedi'i osod yn Oriel",
          remove: 'Tynnu o Oriel',
          tipChrome: 'Gall Oriel osod yr estyniad hwn ar iPhone a iPad — tapiwch Ychwanegu at Oriel.',
          tipFirefox: 'Gall Oriel osod yr ychwanegyn Firefox hwn ar iPhone a iPad — tapiwch Ychwanegu at Oriel.'
        },
        sr: {
          add: 'Dodaj u Oriel',
          addTheme: 'Dodaj temu u Oriel',
          installing: 'Instaliranje…',
          installed: 'Instalirano u Oriel',
          remove: 'Ukloni iz Oriel',
          tipChrome: 'Oriel može da instalira ovo proširenje na iPhone i iPad — dodirnite Dodaj u Oriel.',
          tipFirefox: 'Oriel može da instalira ovaj Firefox dodatak na iPhone i iPad — dodirnite Dodaj u Oriel.'
        },
        bs: {
          add: 'Dodaj u Oriel',
          addTheme: 'Dodaj temu u Oriel',
          installing: 'Instaliranje…',
          installed: 'Instalirano u Oriel',
          remove: 'Ukloni iz Oriel',
          tipChrome: 'Oriel može instalirati ovo proširenje na iPhone i iPad — dodirnite Dodaj u Oriel.',
          tipFirefox: 'Oriel može instalirati ovaj Firefox dodatak na iPhone i iPad — dodirnite Dodaj u Oriel.'
        },
        ne: {
          add: 'Oriel मा थप्नुहोस्',
          addTheme: 'Oriel मा थिम थप्नुहोस्',
          installing: 'इन्स्टल हुँदै…',
          installed: 'Oriel मा इन्स्टल भयो',
          remove: 'Oriel बाट हटाउनुहोस्',
          tipChrome: 'Oriel ले यो एक्स्टेन्सन iPhone र iPad मा इन्स्टल गर्न सक्छ — Oriel मा थप्नुहोस् ट्याप गर्नुहोस्।',
          tipFirefox: 'Oriel ले यो Firefox एड-अन iPhone र iPad मा इन्स्टल गर्न सक्छ — Oriel मा थप्नुहोस् ट्याप गर्नुहोस्।'
        },
        mn: {
          add: 'Oriel-д нэмэх',
          addTheme: 'Oriel-д загвар нэмэх',
          installing: 'Суулгаж байна…',
          installed: 'Oriel-д суулгасан',
          remove: 'Oriel-ээс устгах',
          tipChrome: 'Oriel энэ өргөтгөлийг iPhone болон iPad дээр суулгаж чадна — Oriel-д нэмэх дээр дарна уу.',
          tipFirefox: 'Oriel энэ Firefox нэмэлтийг iPhone болон iPad дээр суулгаж чадна — Oriel-д нэмэх дээр дарна уу.'
        }
      };

      // Aliases
      STRINGS.no = STRINGS.nb;
      STRINGS['pt-pt'] = STRINGS.pt;
      STRINGS['zh-hans'] = STRINGS['zh-cn'];
      STRINGS['zh-hant'] = STRINGS['zh-tw'];
      STRINGS.zh = STRINGS['zh-cn'];
      STRINGS.in = STRINGS.id;
      STRINGS.iw = STRINGS.he;
      STRINGS.tl = STRINGS.fil;
      STRINGS['sr-latn'] = STRINGS.sr;
      STRINGS['sr-cyrl'] = STRINGS.sr;

      function resolveLang() {
        var raw = (document.documentElement.lang || navigator.language || 'en').toLowerCase().replace(/_/g, '-');
        if (STRINGS[raw]) return raw;
        var base = raw.split('-')[0];
        if (raw.indexOf('es-') === 0 && raw !== 'es' && STRINGS['es-419']) return 'es-419';
        if (raw === 'pt-br' || raw.indexOf('pt-br') === 0) return 'pt-br';
        if (STRINGS[base]) return base;
        return 'en';
      }

      function pack() {
        return STRINGS[resolveLang()] || STRINGS.en;
      }

      function norm(t) {
        return (t || '').replace(/\s+/g, ' ').trim();
      }

      // Multilingual “add/install” verbs + Chrome/Brave brand ⇒ install CTA.
      var ADD_VERBS = new RegExp(
        [
          'add to', 'get',
          'toevoegen', 'toev\\.?',
          'hinzufügen', 'hinzufuegen',
          'ajouter',
          'añadir', 'anadir', 'agregar',
          'aggiungi',
          'adicionar',
          'dodaj',
          'добавить', 'додати',
          'přidat', 'pridať',
          'hozzáadás', 'hozzaadas',
          'adaug',
          'lägg till', 'lagg till', 'føj', 'foj', 'legg til', 'lisää', 'lisaa',
          'προσθήκη', 'προσθηκη',
          'ekle',
          'إضافة', 'הוסף',
          'जोड़ें', 'जोडें',
          'เพิ่ม',
          'thêm',
          'tambah',
          '追加', '添加', '加到', '新增',
          '추가',
          'afegeix', 'dodaj', 'добавяне', 'pridėti', 'pievienot', 'lisa', 'dodaj'
        ].join('|'),
        'i'
      );

      var REMOVE_VERBS = /remove|verwijder|entfernen|supprimer|quitar|eliminar|rimuovi|remover|usun|удал|odebrat|eltávol|șterge|ta bort|fjern|poista|αφαίρ|kaldır|إزال|הסר|हटा|ลบ|gỡ|hapus|削除|移除|제거|desinstal|uninstall/i;

      // Store CTAs almost always include Latin “Chrome”/“Brave” (plus a few localized brands).
      function hasChromeBrand(t) {
        return /\bChrome\b|\bBrave\b|クロム|크롬|谷歌浏览器|谷歌瀏覽器/i.test(t);
      }
      function hasFirefoxBrand(t) {
        return /\bFirefox\b|ファイアフォックス|파이어폭스|火狐/i.test(t);
      }

      function isChromeInstallLabel(t) {
        t = norm(t);
        if (!t || t.length > 72) return false;
        if (/oriel/i.test(t)) return false;
        if (REMOVE_VERBS.test(t)) return false;
        // Theme-only CWS buttons often say “Add theme” without naming Chrome.
        if (/^(Add theme|Get theme|Toevoegen thema|Thema toevoegen|Thème|Agregar tema|Añadir tema|Thema hinzufügen)$/i.test(t)) {
          return true;
        }
        if (/\btheme\b|\bthema\b|\bthème\b|\btema\b/i.test(t) && ADD_VERBS.test(t) && t.length < 40) {
          return true;
        }
        if (!hasChromeBrand(t)) return false;
        if (ADD_VERBS.test(t)) return true;
        // Exact-ish common forms without relying only on verb list
        if (/^(Add to|Get|Toevoegen aan|Toev\.?\s*aan|Zu .+ hinzufügen|Ajouter à|Añadir a|Agregar a|Aggiungi a|Adicionar ao|Dodaj do|Добавить в|Додати до|Přidat do|Pridať do|Adaugă în|Lägg till i|Føj til|Legg til i|Lisää|Προσθήκη στο|Ekle|إضافة إلى|הוסף ל|जोड़ें|เพิ่ม|Thêm vào|Tambahkan ke|Tambah ke|追加|添加至|加到|추가)\b/i.test(t)) {
          return true;
        }
        return false;
      }

      function isChromeInstalledLabel(t) {
        t = norm(t);
        if (!t || t.length > 72) return false;
        if (!hasChromeBrand(t)) return false;
        return /added to|toegevoegd|hinzugefügt|ajouté|añadid|agregad|aggiunt|adicionad|dodano|добавлен|додано|přidán|pridan|telepítve|instalat|installerad|installeret|installert|asennettu|προστέθ|eklendi|تمت الإضافة|נוסף|जोड़ दिया|เพิ่มแล้ว|đã thêm|ditambahkan|追加済み|已添加|已加|추가됨|geïnstalleerd|installed/i.test(t);
      }

      function isFirefoxInstallLabel(t) {
        t = norm(t);
        if (!t || t.length > 72) return false;
        if (/oriel/i.test(t)) return false;
        if (REMOVE_VERBS.test(t)) return false;
        if (/download file|bestanden downloaden|fichier|archivo|scarica file|baixar arquivo/i.test(t)) return true;
        if (/(install|add)\s+theme|thème|tema|motyw|тема|téma|テーマ|테마|主题|主題/i.test(t) && !/chrome/i.test(t)) return true;
        if (!hasFirefoxBrand(t) && !/download firefox|firefox downloaden|télécharger firefox|descargar firefox|scarica firefox|baixar o firefox|firefox herunterladen|ดาวน์โหลด firefox|firefox をダウンロード|firefox 다운로드|下载.*firefox|下載.*firefox/i.test(t)) {
          return false;
        }
        if (ADD_VERBS.test(t) || /download firefox|firefox downloaden|télécharger firefox|descargar firefox|firefox herunterladen|baixar o firefox|scarica firefox/i.test(t)) {
          return true;
        }
        return /add to firefox|toevoegen aan firefox|zu firefox hinzufügen|ajouter à firefox|añadir a firefox|agregar a firefox|aggiungi a firefox|adicionar ao firefox|dodaj do firefox|добавить в firefox/i.test(t);
      }

      function isChromeRemoveLabel(t) {
        t = norm(t);
        if (!t || t.length > 72) return false;
        if (!REMOVE_VERBS.test(t)) return false;
        if (hasChromeBrand(t)) return true;
        if (/remove from chrome|verwijderen uit chrome|aus chrome entfernen|supprimer (de |d.)chrome|quitar de chrome|eliminar de chrome|rimuovi da chrome|remover do chrome|usuń z chrome|удалить из chrome|remove from brave|verwijderen uit brave/i.test(t)) {
          return true;
        }
        // Short remove CTAs on an installed detail page
        if (/^(Remove|Verwijderen|Entfernen|Supprimer|Quitar|Eliminar|Rimuovi|Remover|Usuń|Удалить|Видалити|Odebrat|Odstrániť|Eltávolítás|Elimină|Ta bort|Fjern|Poista|Κατάργηση|Kaldır|إزالة|הסר|हटाएँ|นำออก|Gỡ|Hapus|Alih keluar|削除|제거|移除|Alisin|Ondoa|Fjarlægja|Neħħi|Tynnu|Ukloni|Премахни|Pašalinti|Noņemt|Eemalda|Bain|Kendu|Verwyder|Hiq|Отстрани|Выдаліць)$/i.test(t)) {
          return true;
        }
        return false;
      }

      function isFirefoxRemoveLabel(t) {
        t = norm(t);
        if (!t || t.length > 72) return false;
        if (!REMOVE_VERBS.test(t)) return false;
        if (hasFirefoxBrand(t)) return true;
        if (/remove|verwijderen|entfernen|supprimer|quitar|eliminar|rimuovi|remover/i.test(t)
            && /extension|add-?on|extensie|erweiterung|extensión|estensione|extensão/i.test(t)) {
          return true;
        }
        return false;
      }

      function isPhoneIncompatText(text) {
        text = norm(text);
        if (!text || text.length < 10 || text.length > 240) return false;
        if (/Item currently unavailable|Artikel momenteel niet beschikbaar|Element derzeit nicht verfügbar|Élément actuellement indisponible|Elemento no disponible|Elemento attualmente non disponibile|Item indisponível|Элемент сейчас недоступен|項目目前無法使用|目前无法使用|현재 사용할 수 없음|現在利用できません/i.test(text)) return true;
        if (/not compatible with (a )?(phone|mobile|device)|niet compatibel met (een )?(telefoon|mobiel)|nicht (mit|für) (einem )?(telefon|handy|mobilgerät)|pas compatible avec (un )?(téléphone|mobile)|no compatible con (un )?(teléfono|móvil|dispositivo)|non compatibile con (un )?(telefono|dispositivo)|não compatível com (um )?(telefone|dispositivo)|не совместим|غير متوافق|غير متوافقة|غير متوافق مع|スマホ|スマートフォン|携帯電話|スマートフォンには対応|モバイル|手机|手機|모바일|휴대전화/i.test(text)) return true;
        if (/not available (on|for) (your )?(phone|mobile|ios|iphone|ipad)|niet beschikbaar op|nicht verfügbar|pas disponible|no disponible|non disponibile|não disponível|не доступ|غير متاح|iPhone|iPad|iOS/i.test(text)
            && /(phone|mobile|telefoon|telefon|téléphone|móvil|telefono|スマートフォン|手机|手機|모바일|iphone|ipad|ios)/i.test(text)) {
          return true;
        }
        if (/only (works|available) on (desktop|computer)|alleen (beschikbaar|werkzaam) op|nur (auf|für) (dem )?desktop|uniquement (sur|disponible)|solo (en|disponible)|solo su|apenas (no|em)|только на|فقط على|デスクトップのみ|仅限电脑|僅限電腦|데스크톱에서만/i.test(text)) return true;
        if (/requires? chrome|chrome (for )?(desktop|mac|windows) (required|nodig|erforderlich|requis|necesario|necessario|necessário)/i.test(text)) return true;
        return false;
      }

      function isNeedFirefoxBanner(text) {
        text = norm(text);
        if (!text || text.length < 10 || text.length > 240) return false;
        if (/you.?ll need firefox|need to download firefox|download firefox|firefox downloaden|firefox herunterladen|télécharger firefox|descargar firefox|scarica firefox|baixar o firefox|скачать firefox|הורד את firefox|تنزيل firefox|firefox をダウンロード|firefox 다운로드|下载 firefox|下載 firefox|cần firefox|perlu firefox|firefox gerekli/i.test(text)) return true;
        if (/to use (these|this) add-?ons?/i.test(text) && /firefox/i.test(text)) return true;
        if (/je hebt firefox nodig|sie benötigen firefox|vous avez besoin de firefox|necesitas firefox|hai bisogno di firefox|você precisa do firefox|нужен firefox/i.test(text)) return true;
        if (/only available (for|on) (desktop )?firefox|alleen beschikbaar|nur für firefox|uniquement (pour|sur) firefox|solo (para|en) firefox/i.test(text)) return true;
        if (/not available (on|for) (your )?(phone|mobile|ios|iphone|ipad|android)/i.test(text)) return true;
        return false;
      }

      window.__orielStoreI18n = {
        lang: resolveLang,
        t: function (key) {
          var p = pack();
          return (p && p[key]) || STRINGS.en[key] || key;
        },
        normalize: norm,
        isChromeInstallLabel: isChromeInstallLabel,
        isChromeInstalledLabel: isChromeInstalledLabel,
        isChromeRemoveLabel: isChromeRemoveLabel,
        isFirefoxInstallLabel: isFirefoxInstallLabel,
        isFirefoxRemoveLabel: isFirefoxRemoveLabel,
        isPhoneIncompatText: isPhoneIncompatText,
        isNeedFirefoxBanner: isNeedFirefoxBanner,
        hasChromeBrand: hasChromeBrand,
        hasFirefoxBrand: hasFirefoxBrand
      };
    })();
    """#
}
