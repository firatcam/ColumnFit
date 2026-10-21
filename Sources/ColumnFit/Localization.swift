import Foundation

/// Supported UI languages. English is the default.
enum Lang: String, CaseIterable {
    case en, de, tr, fr, es

    /// Each language is listed under its own name so it can always be found.
    var nativeName: String {
        switch self {
        case .en: return "English"
        case .de: return "Deutsch"
        case .tr: return "Türkçe"
        case .fr: return "Français"
        case .es: return "Español"
        }
    }
}

/// Localizable string keys.
enum S {
    case autoOn, autoOff, resizeNow, hideCursor
    case calibrate, diagnostics, forceColumnView
    case launchAtLogin, openAccessibility, language, about, quit
    case calTitle, calHelp, calX, calY, calGap, calSettle, calShow, calTest, calNotFound
    case switchTitle, switchInfo, switchOK, cancel
}

enum L10n {
    static var current: Lang { Prefs.language }

    static func t(_ key: S) -> String {
        table[current]?[key] ?? table[.en]?[key] ?? "\(key)"
    }

    private static let table: [Lang: [S: String]] = [
        .en: en, .de: de, .tr: tr, .fr: fr, .es: es,
    ]

    // MARK: English (default)

    private static let en: [S: String] = [
        .autoOn: "Auto-Resize: On",
        .autoOff: "Auto-Resize: Off",
        .resizeNow: "Resize Now",
        .hideCursor: "Hide Pointer While Resizing",
        .calibrate: "Calibrate…",
        .diagnostics: "Diagnostics…",
        .forceColumnView: "Switch Finder to Column View",
        .launchAtLogin: "Launch at Login",
        .openAccessibility: "Open Accessibility Settings…",
        .language: "Language",
        .about: "About ColumnFit",
        .quit: "Quit ColumnFit",
        .calTitle: "ColumnFit – Calibration",
        .calHelp: "Open a Finder window in Column View and select a folder. Move the red point along the divider line until its centre sits on the draggable edge of the newly opened column, then press Test.",
        .calX: "Horizontal position (+ right, − left)",
        .calY: "Position along the divider (bottom → top)",
        .calGap: "Time between clicks (ms)",
        .calSettle: "Delay after selection (ms)",
        .calShow: "Show Point",
        .calTest: "Test (double-click)",
        .calNotFound: "No Finder window in Column View was found (or the Accessibility permission is missing).",
        .switchTitle: "Switch Finder to Column View?",
        .switchInfo: "Finder will restart briefly.",
        .switchOK: "Switch",
        .cancel: "Cancel",
    ]

    // MARK: Deutsch

    private static let de: [S: String] = [
        .autoOn: "Automatische Anpassung: An",
        .autoOff: "Automatische Anpassung: Aus",
        .resizeNow: "Jetzt anpassen",
        .hideCursor: "Zeiger beim Anpassen ausblenden",
        .calibrate: "Kalibrieren…",
        .diagnostics: "Diagnose…",
        .forceColumnView: "Finder auf Spaltenansicht umstellen",
        .launchAtLogin: "Beim Anmelden starten",
        .openAccessibility: "Bedienungshilfen-Einstellungen öffnen…",
        .language: "Sprache",
        .about: "Über ColumnFit",
        .quit: "ColumnFit beenden",
        .calTitle: "ColumnFit – Kalibrierung",
        .calHelp: "Öffne ein Finder-Fenster in der Spaltenansicht und wähle einen Ordner aus. Verschiebe den roten Punkt entlang der Trennlinie, bis seine Mitte auf dem ziehbaren Rand der neu geöffneten Spalte liegt, und klicke dann auf „Testen“.",
        .calX: "Horizontale Position (+ rechts, − links)",
        .calY: "Position entlang der Trennlinie (unten → oben)",
        .calGap: "Zeit zwischen den Klicks (ms)",
        .calSettle: "Verzögerung nach der Auswahl (ms)",
        .calShow: "Punkt anzeigen",
        .calTest: "Testen (Doppelklick)",
        .calNotFound: "Es wurde kein Finder-Fenster in der Spaltenansicht gefunden (oder die Bedienungshilfen-Berechtigung fehlt).",
        .switchTitle: "Finder auf Spaltenansicht umstellen?",
        .switchInfo: "Der Finder wird dafür kurz neu gestartet.",
        .switchOK: "Umstellen",
        .cancel: "Abbrechen",
    ]

    // MARK: Türkçe

    private static let tr: [S: String] = [
        .autoOn: "Otomatik Boyutlandırma: Açık",
        .autoOff: "Otomatik Boyutlandırma: Kapalı",
        .resizeNow: "Şimdi Boyutlandır",
        .hideCursor: "Boyutlandırırken İmleci Gizle",
        .calibrate: "Kalibrasyon…",
        .diagnostics: "Tanılama…",
        .forceColumnView: "Finder'ı Sütun Görünümüne Geçir",
        .launchAtLogin: "Oturum Açıldığında Başlat",
        .openAccessibility: "Erişilebilirlik Ayarlarını Aç…",
        .language: "Dil",
        .about: "ColumnFit Hakkında",
        .quit: "ColumnFit'ten Çık",
        .calTitle: "ColumnFit – Kalibrasyon",
        .calHelp: "Finder'da Sütun Görünümü'nde bir pencere açın ve bir klasör seçin. Kırmızı noktayı ayırıcı çizgi boyunca, merkezi yeni açılan sütunun sürüklenebilir kenarına gelene kadar kaydırın, sonra Test'e basın.",
        .calX: "Yatay konum (+ sağa, − sola)",
        .calY: "Ayırıcı çizgi boyunca konum (alt → üst)",
        .calGap: "Tıklamalar arası süre (ms)",
        .calSettle: "Seçimden sonra bekleme (ms)",
        .calShow: "Noktayı Göster",
        .calTest: "Test Et (çift tık)",
        .calNotFound: "Sütun Görünümü'nde bir Finder penceresi bulunamadı (veya Erişilebilirlik izni yok).",
        .switchTitle: "Finder Sütun Görünümü'ne geçirilsin mi?",
        .switchInfo: "Bunun için Finder kısa süreliğine yeniden başlatılır.",
        .switchOK: "Geçir",
        .cancel: "İptal",
    ]

    // MARK: Français

    private static let fr: [S: String] = [
        .autoOn: "Ajustement automatique : activé",
        .autoOff: "Ajustement automatique : désactivé",
        .resizeNow: "Ajuster maintenant",
        .hideCursor: "Masquer le pointeur pendant l'ajustement",
        .calibrate: "Calibrer…",
        .diagnostics: "Diagnostic…",
        .forceColumnView: "Passer le Finder en affichage par colonnes",
        .launchAtLogin: "Ouvrir au démarrage de la session",
        .openAccessibility: "Ouvrir les réglages d'accessibilité…",
        .language: "Langue",
        .about: "À propos de ColumnFit",
        .quit: "Quitter ColumnFit",
        .calTitle: "ColumnFit – Calibrage",
        .calHelp: "Ouvrez une fenêtre du Finder en affichage par colonnes et sélectionnez un dossier. Déplacez le point rouge le long de la ligne de séparation jusqu'à ce que son centre se trouve sur le bord déplaçable de la colonne qui vient de s'ouvrir, puis cliquez sur Tester.",
        .calX: "Position horizontale (+ droite, − gauche)",
        .calY: "Position le long de la ligne (bas → haut)",
        .calGap: "Délai entre les clics (ms)",
        .calSettle: "Délai après la sélection (ms)",
        .calShow: "Afficher le point",
        .calTest: "Tester (double-clic)",
        .calNotFound: "Aucune fenêtre du Finder en affichage par colonnes n'a été trouvée (ou l'autorisation d'accessibilité est manquante).",
        .switchTitle: "Passer le Finder en affichage par colonnes ?",
        .switchInfo: "Le Finder va redémarrer brièvement.",
        .switchOK: "Passer",
        .cancel: "Annuler",
    ]

    // MARK: Español

    private static let es: [S: String] = [
        .autoOn: "Ajuste automático: activado",
        .autoOff: "Ajuste automático: desactivado",
        .resizeNow: "Ajustar ahora",
        .hideCursor: "Ocultar el puntero al ajustar",
        .calibrate: "Calibrar…",
        .diagnostics: "Diagnóstico…",
        .forceColumnView: "Cambiar el Finder a vista de columnas",
        .launchAtLogin: "Abrir al iniciar sesión",
        .openAccessibility: "Abrir ajustes de accesibilidad…",
        .language: "Idioma",
        .about: "Acerca de ColumnFit",
        .quit: "Salir de ColumnFit",
        .calTitle: "ColumnFit – Calibración",
        .calHelp: "Abre una ventana del Finder en vista de columnas y selecciona una carpeta. Mueve el punto rojo a lo largo de la línea divisoria hasta que su centro quede sobre el borde arrastrable de la columna recién abierta y pulsa Probar.",
        .calX: "Posición horizontal (+ derecha, − izquierda)",
        .calY: "Posición a lo largo de la línea (abajo → arriba)",
        .calGap: "Tiempo entre clics (ms)",
        .calSettle: "Retardo tras la selección (ms)",
        .calShow: "Mostrar punto",
        .calTest: "Probar (doble clic)",
        .calNotFound: "No se encontró ninguna ventana del Finder en vista de columnas (o falta el permiso de accesibilidad).",
        .switchTitle: "¿Cambiar el Finder a vista de columnas?",
        .switchInfo: "El Finder se reiniciará brevemente.",
        .switchOK: "Cambiar",
        .cancel: "Cancelar",
    ]
}
