///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsDeDe extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsDeDe({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.deDe,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <de-DE>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsDeDe _root = this; // ignore: unused_field

	@override 
	TranslationsDeDe $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsDeDe(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$account$de_DE account = _Translations$account$de_DE._(_root);
	@override late final _Translations$agent$de_DE agent = _Translations$agent$de_DE._(_root);
	@override late final _Translations$agentTask$de_DE agentTask = _Translations$agentTask$de_DE._(_root);
	@override late final _Translations$appeal$de_DE appeal = _Translations$appeal$de_DE._(_root);
	@override late final _Translations$billing$de_DE billing = _Translations$billing$de_DE._(_root);
	@override late final _Translations$channel$de_DE channel = _Translations$channel$de_DE._(_root);
	@override late final _Translations$chat$de_DE chat = _Translations$chat$de_DE._(_root);
	@override late final _Translations$common$de_DE common = _Translations$common$de_DE._(_root);
	@override late final _Translations$complaint$de_DE complaint = _Translations$complaint$de_DE._(_root);
	@override late final _Translations$complaintReason$de_DE complaintReason = _Translations$complaintReason$de_DE._(_root);
	@override late final _Translations$contact$de_DE contact = _Translations$contact$de_DE._(_root);
	@override late final _Translations$discovery$de_DE discovery = _Translations$discovery$de_DE._(_root);
	@override late final _Translations$enterpriseApp$de_DE enterpriseApp = _Translations$enterpriseApp$de_DE._(_root);
	@override late final _Translations$enterpriseOa$de_DE enterpriseOa = _Translations$enterpriseOa$de_DE._(_root);
	@override late final _Translations$error$de_DE error = _Translations$error$de_DE._(_root);
	@override late final _Translations$group$de_DE group = _Translations$group$de_DE._(_root);
	@override late final _Translations$groupCategory$de_DE groupCategory = _Translations$groupCategory$de_DE._(_root);
	@override late final _Translations$groupDiscovery$de_DE groupDiscovery = _Translations$groupDiscovery$de_DE._(_root);
	@override late final _Translations$groupList$de_DE groupList = _Translations$groupList$de_DE._(_root);
	@override late final _Translations$groupSchedule$de_DE groupSchedule = _Translations$groupSchedule$de_DE._(_root);
	@override late final _Translations$groupTag$de_DE groupTag = _Translations$groupTag$de_DE._(_root);
	@override late final _Translations$groupTask$de_DE groupTask = _Translations$groupTask$de_DE._(_root);
	@override late final _Translations$groupVote$de_DE groupVote = _Translations$groupVote$de_DE._(_root);
	@override late final _Translations$main$de_DE main = _Translations$main$de_DE._(_root);
	@override late final _Translations$mention$de_DE mention = _Translations$mention$de_DE._(_root);
	@override late final _Translations$momentFriendPicker$de_DE momentFriendPicker = _Translations$momentFriendPicker$de_DE._(_root);
	@override late final _Translations$momentNotify$de_DE momentNotify = _Translations$momentNotify$de_DE._(_root);
	@override late final _Translations$organization$de_DE organization = _Translations$organization$de_DE._(_root);
	@override late final _Translations$passport$de_DE passport = _Translations$passport$de_DE._(_root);
	@override late final _Translations$splash$de_DE splash = _Translations$splash$de_DE._(_root);
	@override late final _Translations$talkRecord$de_DE talkRecord = _Translations$talkRecord$de_DE._(_root);
	@override late final _Translations$welcome$de_DE welcome = _Translations$welcome$de_DE._(_root);
	@override late final _Translations$workspace$de_DE workspace = _Translations$workspace$de_DE._(_root);
}

// Path: account
class _Translations$account$de_DE extends Translations$account$zh_CN {
	_Translations$account$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get account => 'Konto';
	@override String get accountSecurity => 'Kontosicherheit';
	@override String get avatar => 'Profilbild';
	@override String get accountSecurityEnhance => 'Kontosicherheit verbessern';
	@override String get bindMobile => 'Mobilfunknummer verbinden';
	@override String get bindMobileFor => 'Für Anmeldung, Passwort-Wiederherstellung und Empfang wichtiger Benachrichtigungen';
	@override String get linkEmail => 'E-Mail verknüpfen';
	@override String get linkEmailFor => 'Für Anmeldung, Identitätsprüfung und Erhalt von Rechnungen';
	@override String get codeSentToEmail => 'Bestätigungscode an E-Mail gesendet';
	@override String get codeSentToMobile => 'Bestätigungscode an Mobilfunknummer gesendet';
	@override String get currentDevice => 'Aktuelles Gerät';
	@override String get deviceAvailableSpace => 'Verfügbarer Speicherplatz auf dem Gerät';
	@override String get deviceList => 'Geräteliste';
	@override String get deviceName => 'Gerätename';
	@override String get deviceType => 'Gerätetyp';
	@override String get deviceUsedSpace => 'Vom Gerät verwendeter Speicherplatz';
	@override String get email => 'E-Mail';
	@override String get forgotPassword => 'Passwort vergessen?';
	@override String get gender => 'Geschlecht';
	@override String get groupQrcode => 'Gruppen-QR-Code';
	@override String get hintLoginAccount => 'Konto/E-Mail';
	@override String get logOut => 'Abmelden';
	@override String get areYouSureLogOut => 'Möchten Sie sich wirklich abmelden?';
	@override String get login => 'Anmelden';
	@override String get loginDeviceManagement => 'Geräteverwaltung';
	@override String get loginEmail => 'Anmelde-E-Mail';
	@override String get logoutAccount => 'Konto löschen';
	@override String get mobile => 'Mobilfunk';
	@override String get mobileQuickLogin => 'Schnellanmeldung';
	@override String get myAccount => 'Mein Konto';
	@override String get myQrcode => 'Mein QR-Code';
	@override String get newPassword => 'Neues Passwort';
	@override String get newlyRegisteredPeople => 'Kürzlich registrierte Personen';
	@override String get nickname => 'Spitzname';
	@override String get nicknameHint => 'Spitzname eingeben';
	@override String get password => 'Passwort';
	@override String get recoverPassword => 'Passwort wiederherstellen';
	@override String get birthday => 'Geburtstag';
	@override String get region => 'Region';
	@override String get retypePassword => 'Passwort erneut eingeben';
	@override String get scanQrCode => 'QR-Code scannen';
	@override String get setNickname => 'Spitzname festlegen';
	@override String get signature => 'Signatur';
	@override String get signup => 'Registrieren';
	@override String get sourceQrcode => 'Durch Scannen hinzufügen';
	@override String get changeEmail => 'E-Mail ändern';
	@override String get bindEmail => 'E-Mail binden';
	@override String get currentEmail => 'Aktuelle E-Mail';
	@override String get setPassword => 'Passwort festlegen';
	@override String get setLoginPassword => 'Anmeldepasswort festlegen';
	@override String get enhanceAccountSecurity => 'Kontosicherheit verbessern';
	@override String get passwordLengthRequirement => 'Passwortlänge: 4-32 beliebige Zeichen';
	@override String passwordMinLength({required Object min}) => 'Passwort muss mindestens ${min} Zeichen lang sein';
	@override String get pleaseEnterPassword => 'Bitte Passwort eingeben';
	@override String get changeMobile => 'Mobilfunknummer ändern';
	@override String get currentMobile => 'Aktuelle Mobilfunknummer';
	@override String get newMobile => 'Neue Mobilfunknummer';
	@override String get enterMobileHint => 'Mobilfunknummer eingeben';
	@override String get privacyLogoutAccount => 'Konto löschen';
	@override String get wallet => 'Wallet';
	@override String get changeLoginPassword => 'Anmeldepasswort ändern';
	@override String get otherDevice => 'Anderes Gerät';
	@override String get loginPassword => 'Anmeldepasswort';
	@override String get loginPasswordDesc => 'Wird für die Anmeldung im IMBoy-Konto verwendet';
	@override String get oldPassword => 'Altes Passwort';
	@override String get enterOldPassword => 'Bitte altes Passwort eingeben';
	@override String get enterNewPassword => 'Bitte neues Passwort eingeben';
	@override String get enterNewPasswordAgain => 'Bitte neues Passwort erneut eingeben';
	@override String get myQRCode => 'Mein QR-Code';
	@override String get profile => 'Profil';
	@override String get setGender => 'Geschlecht festlegen';
	@override String get setBirthday => 'Geburtstag festlegen';
	@override String get nicknameRules => '• Spitznamenlänge: 2-24 Zeichen • Darf nicht nur aus Leerzeichen oder Emojis bestehen • Darf keine sensiblen Wörter enthalten • Änderungen werden in allen Chats angezeigt';
	@override String get refreshDeviceKey => 'Geräteschlüssel aktualisieren';
	@override String get refreshDeviceKeyHint => 'Wenn Nachrichten nicht entschlüsselt werden können, Schlüssel hier aktualisieren';
	@override String get refreshingDeviceKey => 'Geräteschlüssel wird aktualisiert...';
	@override String get deviceKeyRefreshed => 'Geräteschlüssel aktualisiert';
	@override String get rechargeTitle => 'Aufladen';
	@override String get rechargeAmountHint => 'Betrag eingeben (Yuan), 0.01–10000';
	@override String get rechargeAmountExample => 'z. B. 100';
	@override String get e2eeDeviceIdLabel => 'Geräte-ID';
	@override String get webQRLoginTitle => 'Per QR-Code anmelden';
	@override String get webQRLoginHint => 'QR-Code mit der ImBoy-App scannen';
	@override String get webSwitchToPassword => 'Mit Passwort anmelden';
	@override String get webPasswordLoginTitle => 'Konto-Anmeldung';
	@override String get webAccountHint => 'Konto/Handy/E-Mail eingeben';
	@override String get webPasswordHint => 'Passwort eingeben';
	@override String get pleaseRelogin => 'Bitte neu anmelden';
	@override String get otherLoginMethods => 'Weitere Anmeldemethoden';
	@override String get payMethodTitle => 'Zahlungsart wählen';
	@override String get payMethodAlipay => 'Alipay';
	@override String get payMethodWechat => 'WeChat Pay';
	@override String get payMethodWallet => 'Wallet-Guthaben';
	@override String get payMethodMock => 'Testzahlung (nur Entwicklung)';
	@override String get payMethodComingSoon => 'Diese Zahlungsart ist bald verfügbar';
	@override String get payCancelled => 'Zahlung abgebrochen';
	@override late final _Translations$account$alipaySim$de_DE alipaySim = _Translations$account$alipaySim$de_DE._(_root);
	@override String get logoutPendingHeader => 'Status des Löschantrags';
	@override String logoutPendingBanner({required Object date}) => 'Löschantrag eingereicht, Abschluss voraussichtlich am ${date}';
	@override String get logoutCancelRequest => 'Löschantrag zurückziehen';
	@override String get logoutCancelledNote => 'Löschantrag zurückgezogen';
	@override String get logoutRetainedHeader => 'Hinweis zur Datenaufbewahrung';
	@override String get logoutRetainedNote => 'Nach Abschluss der Löschung werden Audit-Protokolle und Finanzunterlagen gesetzlich vorgeschrieben aufbewahrt und anonymisiert; von Ihnen geführte Gruppen/Arbeitsbereiche/Kanäle werden vorrangig an Nachfolgemitglieder übertragen';
	@override String get bindAlipay => 'Alipay verknüpfen';
	@override String get unbindAlipay => 'Verknüpfung aufheben';
	@override String get confirmUnbindAlipay => 'Verknüpfung aufheben bestätigen';
}

// Path: agent
class _Translations$agent$de_DE extends Translations$agent$zh_CN {
	_Translations$agent$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get plazaTitle => 'KI-Assistenten';
	@override String get transparencyBanner => 'Alle Mitglieder hier sind KI-Assistenten und klar als solche gekennzeichnet. In verschlüsselten Chats gibt es nur echte Menschen.';
	@override String get searchHint => 'Assistenten suchen';
	@override String get emptyTitle => 'Noch keine KI-Assistenten. Schau später wieder vorbei.';
	@override String get searchEmpty => 'Keine passenden Assistenten';
	@override String get sendMessage => 'Nachricht';
	@override String get badgeAi => 'KI';
	@override String get badgeOfficial => 'Offiziell';
	@override String get badgeAiA11y => 'KI-Assistent';
	@override String get badgeOfficialA11y => 'Offizielles Konto';
	@override String get legacyBotGoPlaza => 'Zu den KI-Assistenten';
	@override String get legacyBotMigrated => 'Dieser Bot-Zugang wurde aktualisiert. Bitte chatten Sie mit den Assistenten im Bereich KI-Assistenten';
}

// Path: agentTask
class _Translations$agentTask$de_DE extends Translations$agentTask$zh_CN {
	_Translations$agentTask$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'KI-Aufgabe';
	@override String get working => 'Wird ausgeführt';
	@override String get submitted => 'Eingereicht';
	@override String get progress => 'In Bearbeitung';
	@override String get completed => 'Abgeschlossen';
	@override String get failed => 'Fehlgeschlagen';
	@override String get cancelled => 'Abgebrochen';
	@override String get awaitingApproval => 'Genehmigung ausstehend';
	@override String get approve => 'Genehmigen';
	@override String get reject => 'Ablehnen';
}

// Path: appeal
class _Translations$appeal$de_DE extends Translations$appeal$zh_CN {
	_Translations$appeal$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Maßnahmen & Einspruch';
	@override String get actionsSection => 'Maßnahmen gegen mich';
	@override String get actionsEmpty => 'Keine Maßnahmen';
	@override String get appealsSection => 'Meine Einsprüche';
	@override String get appealsEmpty => 'Keine Einsprüche';
	@override String get dialogTitle => 'Einspruch einlegen';
	@override String get reasonPlaceholder => 'Begründung angeben (erforderlich)';
	@override String get submit => 'Einspruch senden';
	@override String get submitFailed => 'Senden fehlgeschlagen';
	@override String get appealedTag => 'Eingesprochen';
	@override String get appealableTag => 'Einspruch möglich';
	@override String get actionWarning => 'Warnung';
	@override String get actionGroupMute => 'Gruppen-Stummschaltung';
	@override String get actionGroupKick => 'Aus Gruppe entfernt';
	@override String get actionReject => 'Inhalt abgelehnt';
	@override String get actionAccountRestrict => 'Konto eingeschränkt';
	@override String get actionContentRemoval => 'Inhalt entfernt';
	@override String get statusPending => 'In Prüfung';
	@override String get statusAccepted => 'Aufgehoben';
	@override String get statusRejected => 'Aufrechterhalten';
	@override String get allClearTitle => 'Alles in Ordnung';
	@override String get allClearSubtitle => 'Keine Maßnahmen gegen dich, kein Einspruch erforderlich.';
}

// Path: billing
class _Translations$billing$de_DE extends Translations$billing$zh_CN {
	_Translations$billing$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Abo-Pläne';
	@override String get planPeriodMonthly => 'Monatlich';
	@override String get planPeriodYearly => 'Jährlich';
	@override String get subscribe => 'Jetzt abonnieren';
	@override String get currentPlan => 'Aktueller Plan';
	@override String get noPlans => 'Noch keine Pläne verfügbar. Bleiben Sie gespannt';
	@override String get loadFailed => 'Laden fehlgeschlagen. Zum Wiederholen nach unten ziehen';
	@override String get retry => 'Wiederholen';
	@override String get paySuccess => 'Abo erfolgreich abgeschlossen';
	@override String get payFailed => 'Zahlung fehlgeschlagen';
	@override String get payCancelled => 'Zahlung abgebrochen';
	@override String get payMethodTitle => 'Zahlungsart wählen';
	@override String get payMethodMock => 'Testzahlung (nur Entwicklung)';
	@override String get payMethodAlipay => 'Alipay';
	@override String get payMethodWechat => 'WeChat Pay';
	@override String get payMethodComingSoon => 'Diese Zahlungsart ist bald verfügbar';
	@override String get quotaUnlimited => 'Unbegrenzt';
}

// Path: channel
class _Translations$channel$de_DE extends Translations$channel$zh_CN {
	_Translations$channel$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get composeLeaveImagesLost => 'Ausgewählte Bilder werden nicht gespeichert. Trotzdem verlassen?';
	@override String get title => 'Kanäle';
	@override String get loading => 'Laden...';
	@override String get subscribed => 'Abonniert';
	@override String get managed => 'Verwaltet';
	@override String get writeArticle => 'Beitrag schreiben';
	@override String get discover => 'Entdecken';
	@override String get create => 'Kanal erstellen';
	@override String get creationRecoveryUnavailable => 'Erstellungsergebnis unbekannt, bitte später erneut versuchen';
	@override String get searchHint => 'Kanalname oder ID suchen';
	@override String get noResults => 'Keine Kanäle gefunden';
	@override String get noRecommendedChannels => 'Keine empfohlenen Kanäle Schauen Sie später vorbei';
	@override String get noSubscribedChannels => 'Keine abonnierten Kanäle Entdecke mehr Kanäle';
	@override String get noManagedChannels => 'Keine verwalteten Kanäle Erstelle einen Kanal um zu beginnen';
	@override String get subscribers => 'Abonnenten';
	@override String get subscribe => 'Abonnieren';
	@override String get subscribeSuccess => 'Erfolgreich abonniert';
	@override String get subscribeFailed => 'Abonnieren fehlgeschlagen';
	@override String get unsubscribe => 'Abo beenden';
	@override String get unsubscribeConfirm => 'Abo beenden';
	@override String get unsubscribeConfirmDesc => 'Möchten Sie dieses Abo wirklich beenden? Sie erhalten keine Nachrichten mehr.';
	@override String get share => 'Teilen';
	@override String get shareNotImplemented => 'Teilen-Funktion kommt bald';
	@override String get nameLabel => 'Kanalname';
	@override String get nameHint => 'Kanalnamen eingeben';
	@override String get nameRequired => 'Kanalname ist erforderlich';
	@override String get nameTooLong => 'Kanalname darf 50 Zeichen nicht überschreiten';
	@override String get descriptionLabel => 'Beschreibung';
	@override String get descriptionHint => 'Beschreiben Sie Ihren Kanal (optional)';
	@override String get customIdLabel => 'Benutzerdefinierte ID (optional)';
	@override String get customIdHint => 'z.B.: mein_kanal';
	@override String get customIdHelper => 'Ermöglicht Suche nach Kanal-ID';
	@override String get customIdInvalid => 'Nur Buchstaben, Zahlen und Unterstriche erlaubt';
	@override String get customIdLength => 'Muss 4-30 Zeichen lang sein';
	@override String get typePublic => 'Öffentlich';
	@override String get typePrivate => 'Privat';
	@override String get typePublicDesc => 'Jeder kann Ihren Kanal finden und abonnieren';
	@override String get typePrivateDesc => 'Nur über Einladungslink zugänglich';
	@override String get createTips => 'Nach Erstellung können Sie Nachrichten an alle Abonnenten senden. Nur Admins können Kanalnachrichten senden.';
	@override String get today => 'Heute';
	@override String get yesterday => 'Gestern';
	@override String get daysAgo => 'Tage her';
	@override String get messages => 'Nachrichten';
	@override String get views => 'Aufrufe';
	@override String get editChannel => 'Kanal bearbeiten';
	@override String get editChannelNotImplemented => 'Kanal bearbeiten kommt bald';
	@override String get manageAdmins => 'Admins verwalten';
	@override String get manageAdminsNotImplemented => 'Admins verwalten kommt bald';
	@override String get manageSubscribers => 'Abonnenten verwalten';
	@override String get manageSubscribersNotImplemented => 'Abonnenten verwalten kommt bald';
	@override String get deleteChannel => 'Kanal löschen';
	@override String get deleteChannelConfirm => 'Sind Sie sicher, dass Sie diesen Kanal löschen möchten? Dies kann nicht rückgängig gemacht werden.';
	@override String get deleteChannelNotImplemented => 'Kanal löschen kommt bald';
	@override String get channelDeleted => 'Kanal gelöscht';
	@override String get deleteChannelFailed => 'Kanal löschen fehlgeschlagen';
	@override String get writeMessage => 'Nachricht schreiben...';
	@override String get publishFailed => 'Veröffentlichung fehlgeschlagen';
	@override String get pinMessage => 'Nachricht anpinnen';
	@override String get unpinMessage => 'Anpinnen aufheben';
	@override String get pinMessageNotImplemented => 'Anpinnen kommt bald';
	@override String get unpinMessageNotImplemented => 'Anpinnen aufheben kommt bald';
	@override String get messagePinned => 'Nachricht angepinnt';
	@override String get messageUnpinned => 'Anpinnen aufgehoben';
	@override String get deleteMessage => 'Nachricht löschen';
	@override String get deleteMessageConfirm => 'Sind Sie sicher, dass Sie diese Nachricht löschen möchten?';
	@override String get messageDeleted => 'Nachricht gelöscht';
	@override String get addAdmin => 'Admin hinzufügen';
	@override String get addAdminSuccess => 'Admin erfolgreich hinzugefügt';
	@override String get addAdminFailed => 'Admin hinzufügen fehlgeschlagen';
	@override String get removeAdmin => 'Admin entfernen';
	@override String get removeAdminConfirm => 'Sind Sie sicher, dass Sie diesen Admin entfernen möchten?';
	@override String get removeAdminSuccess => 'Admin entfernt';
	@override String get removeAdminFailed => 'Admin entfernen fehlgeschlagen';
	@override String get changeRole => 'Rolle ändern';
	@override String get updateRoleSuccess => 'Rolle erfolgreich aktualisiert';
	@override String get updateRoleFailed => 'Rolle aktualisieren fehlgeschlagen';
	@override String get selectFromContacts => 'Aus Kontakten wählen';
	@override String get searchContactsHint => 'Spitzname oder Konto suchen';
	@override String get noContactsToAdd => 'Alle Freunde sind bereits Administratoren';
	@override String get selectRole => 'Rolle wählen';
	@override String get noAdmins => 'Keine Admins vorhanden';
	@override String get roleCreator => 'Ersteller';
	@override String get roleAdmin => 'Admin';
	@override String get roleAdminDesc => 'Kanal verwalten';
	@override String get roleEditor => 'Editor';
	@override String get roleEditorDesc => 'Nachrichten veröffentlichen';
	@override String get searchSubscribers => 'Abonnenten suchen';
	@override String get subscriberSearchHint => 'Nach Name oder ID suchen';
	@override String get noSearchResults => 'Keine passenden Abonnenten gefunden';
	@override String get noSubscribers => 'Keine Abonnenten vorhanden';
	@override String get removeSubscriber => 'Abonnent entfernen';
	@override String get removeSubscriberConfirm => 'Sind Sie sicher, dass Sie diesen Abonnenten entfernen möchten?';
	@override String get removeSubscriberSuccess => 'Abonnent entfernt';
	@override String get removeSubscriberFailed => 'Abonnent entfernen fehlgeschlagen';
	@override String get subscribedAt => 'Abonniert am';
	@override String get viewProfile => 'Profil ansehen';
	@override String get inviteFromContacts => 'Freunde einladen';
	@override String get inviteSearchHint => 'Spitzname oder Konto suchen';
	@override String get noContactsToInvite => 'Alle Freunde bereits eingeladen oder abonniert';
	@override String get inviteSuccess => 'Einladung gesendet';
	@override String get inviteFailed => 'Einladung fehlgeschlagen';
	@override String get updateSuccess => 'Kanal erfolgreich aktualisiert';
	@override String get updateFailed => 'Kanal aktualisieren fehlgeschlagen';
	@override String get typeCannotChange => 'Kann nach Erstellung nicht geändert werden';
	@override String get stats => 'Statistiken';
	@override String get shareToChat => 'An Freund senden';
	@override String get qrcode => 'Kanal-QR-Code';
	@override String qrcodeTips({required Object days, required Object date}) => 'QR-Code ${days} Tage gültig (bis ${date})';
	@override String get defaultName => 'Unbenannter Kanal';
	@override String get noMessagesManaged => 'Der Kanal hat noch keine Inhalte veröffentlicht';
	@override String get noMessagesManagedDesc => 'Als Kanalinhaber können Sie unten den ersten Inhalt veröffentlichen';
	@override String get noMessagesVisitor => 'Abonnieren, um die Inhalte des Kanals zu sehen';
	@override String get noMessagesVisitorDesc => 'Die Inhalte dieses Kanals werden nach dem Abonnieren angezeigt';
	@override String get noMessagesSubscribed => 'Der Kanal hat noch keine Inhalte veröffentlicht';
	@override String get noMessagesSubscribedDesc => 'Erfolgreich abonniert! Bitte warte auf neue Beiträge des Autors';
	@override String get continueEditing => 'Weiter bearbeiten';
	@override String get publishFirstContent => 'Ersten Inhalt veröffentlichen';
	@override String get noSubscribersDesc => 'Noch keine Abonnenten. Teilen Sie den Kanal mit Ihren Freunden';
	@override String get emoji => 'Emoji';
	@override String get justNow => 'Gerade eben';
	@override String get minutesAgo => 'Min.';
	@override String get hoursAgo => 'Std.';
	@override String get weeksAgo => 'Wo.';
	@override String get visibilityLabel => 'Sichtbarkeit';
	@override String get accessTypeLabel => 'Preismodell';
	@override String get accessTypeFree => 'Kostenlos';
	@override String get accessTypePaid => 'Kostenpflichtig';
	@override String get typePublicPaidDesc => 'Jeder kann den Kanal entdecken und nach dem Kauf abonnieren';
	@override String get typePrivatePaidDesc => 'Nur eingeladene Nutzer können den Kaufvorgang starten und nach Zahlung abonnieren';
	@override String get addImage => 'Bild hinzufügen';
	@override String get allCategories => 'Alle';
	@override String get articleBodyHint => 'Schreiben Sie etwas… Fett, Kursiv, Überschriften, Listen u. a. Formatierungen werden unterstützt';
	@override String get cancelOrder => 'Bestellung stornieren';
	@override String get cancelOrderConfirmMessage => 'Diese offene Bestellung wirklich stornieren? Nach dem Stornieren ist keine Zahlung mehr möglich.';
	@override String get cancelOrderConfirmTitle => 'Stornierung bestätigen';
	@override String get cancelOrderSuccess => 'Bestellung storniert';
	@override String get channelNotFound => 'Kanal nicht gefunden';
	@override String get comment => 'Kommentar';
	@override String get commentDeleteNoPermission => 'Keine Berechtigung zum Löschen dieses Kommentars';
	@override String get commentFailed => 'Kommentar fehlgeschlagen';
	@override String get coverLabel => 'Cover';
	@override String get coverSet => 'Als Cover festgelegt';
	@override String get deleteComment => 'Kommentar löschen';
	@override String get deleteCommentConfirm => 'Diesen Kommentar wirklich löschen?';
	@override String get formatBold => 'Fett';
	@override String get formatHeading => 'Überschrift';
	@override String get formatItalic => 'Kursiv';
	@override String get formatLink => 'Link';
	@override String get formatList => 'Liste';
	@override String get formatQuote => 'Zitat';
	@override String get formatStrikethrough => 'Durchgestrichen';
	@override String get like => 'Gefällt mir';
	@override String get linkTextPlaceholder => 'Linktext';
	@override String get myOrders => 'Meine Bestellungen';
	@override String get noComments => 'Keine Kommentare';
	@override String get noOrders => 'Keine Bestellungen';
	@override String get orderAmount => 'Betrag';
	@override String get orderChannel => 'Kanal';
	@override String get orderContinuePay => 'Weiter bezahlen';
	@override String get orderCreatedAt => 'Bestelldatum';
	@override String get orderDetail => 'Bestelldetails';
	@override String get orderNo => 'Bestellnr.';
	@override String get orderPaidAt => 'Zahlungsdatum';
	@override String get orderPaymentMethod => 'Zahlungsart';
	@override String get orderStatusCancelled => 'Storniert';
	@override String get orderStatusExpired => 'Abgelaufen';
	@override String get orderStatusLabel => 'Status';
	@override String get orderStatusPaid => 'Bezahlt';
	@override String get orderStatusPending => 'Offen';
	@override String get orderStatusRefunded => 'Erstattet';
	@override String get orderStatusRefunding => 'Erstattung läuft';
	@override String get orderSubscriptionPeriod => 'Abo-Zeitraum';
	@override String get orderValidUntil => 'Gültig bis';
	@override String get payAlipay => 'Alipay';
	@override String get payWallet => 'Wallet-Guthaben';
	@override String get payWechat => 'WeChat Pay';
	@override String get preview => 'Vorschau';
	@override String get publish => 'Veröffentlichen';
	@override String get readFull => 'Weiterlesen';
	@override String get refundApply => 'Erstattung beantragen';
	@override String get refundConfirmMessage => 'Für diese Bestellung wirklich eine Erstattung beantragen? Nach der Erstattung wird das Abo beendet.';
	@override String get refundConfirmTitle => 'Erstattung bestätigen';
	@override String get refundSuccess => 'Erstattungsantrag eingereicht';
	@override String get reply => 'Antworten';
	@override String get replyTo => 'Antwort an';
	@override String get sortNewest => 'Neueste';
	@override String get sortPopular => 'Beliebt';
	@override String get titleOptional => 'Titel (optional)';
	@override String get writeComment => 'Kommentar schreiben...';
	@override String get info => 'Kanalinformationen';
	@override String get settings => 'Kanaleinstellungen';
	@override String get inviteAdmins => 'Admins einladen';
	@override String get shareToMyStatus => 'In meinem Status teilen';
	@override String get creator => 'Ersteller';
	@override String get admin => 'Admin';
	@override String get editor => 'Redakteur';
	@override String get privacyTitle => 'Öffentliche Kanäle & Datenschutz';
	@override String get privacyDesc => 'Jeder kann diesen Kanal finden und abonnieren. Ihre Telefonnummer bleibt für andere Abonnenten und Kanal-Admins vollständig verborgen.';
	@override String get aboutThisChannel => 'Über diesen Kanal';
	@override String get changePhoto => 'Foto ändern';
	@override String get addPhoto => 'Foto hinzufügen';
	@override String get addDescription => 'Beschreibung hinzufügen';
	@override String channelCreated({required Object name}) => 'Kanal „${name}“ erstellt';
	@override String startGrowing({required Object name}) => 'Wachse mit „${name}“';
	@override String shareInviteText({required Object name, required Object url}) => 'Folgt gerne meinem Kanal "${name}": ${url}';
	@override String get discussion => 'Diskussion';
	@override String get joinDiscussion => 'Diskussion beitreten';
	@override String get discussionIneligible => 'Abonnieren Sie diesen Kanal, um seiner Diskussionsgruppe beizutreten';
	@override String get essence => 'Highlights';
	@override String get allPosts => 'Alle Beiträge';
	@override String get editPostTags => 'Tags bearbeiten';
	@override String get linkTitle => 'Kanal-Link';
	@override String get copyLink => 'Link kopieren';
	@override String get shareLink => 'Link teilen';
	@override String get linkAccessHint => 'Der Link öffnet den Kanal. Zugriff und Abonnements unterliegen weiterhin den Kanalberechtigungen. Unternehmenskanäle erfordern eine berechtigte Mitgliedschaft.';
	@override String get personalChannelLabel => 'Persönlicher Kanal';
	@override String get enterpriseChannelLabel => 'Interner Unternehmenskanal';
	@override String get subscribePending => 'Abonniert; wird aktualisiert';
	@override String get subscribeRefresh => 'Abonnement aktualisieren';
	@override String unseenUpdatesBanner({required Object count}) => '${count} neue Updates';
}

// Path: chat
class _Translations$chat$de_DE extends Translations$chat$zh_CN {
	_Translations$chat$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get bankCard => 'Bankkarte';
	@override String get receivePayment => 'Empfangen & Zahlen';
	@override String get alreadyMember => 'Bereits Mitglied';
	@override String get awaitingReply => 'Warten auf Antwort';
	@override String get businessCard => 'Visitenkarte';
	@override String get busyTryAgainLater => 'Der Gesprächspartner ist beschäftigt, bitte versuchen Sie es später erneut';
	@override String get later => 'Später';
	@override String peerIsTyping({required Object name}) => '${name} tippt...';
	@override String get chatHoldDownTalk => 'Zum Sprechen gedrückt halten';
	@override String get chatMessage => 'Chatnachrichten';
	@override String get chatSettingMute => 'Nachrichten stummschalten';
	@override String get chatSettingMuted => 'Stummschaltung aktiviert';
	@override String get chatSettingUnmuted => 'Stummschaltung deaktiviert';
	@override String get chatStatusSending => 'Wird gesendet';
	@override String get chatStatusSent => 'Gesendet';
	@override String get chatStatusDelivered => 'Zugestellt';
	@override String get chatStatusSeen => 'Gelesen';
	@override String get createGroupF2f => 'Face-to-Face Gruppe erstellen';
	@override String get displayProfile => 'Mein Profil anzeigen';
	@override String get file => 'Datei';
	@override String get unknownFile => 'Unbekannte Datei';
	@override String get fileSize => 'Dateigröße';
	@override String get forward => 'Weiterleiten';
	@override String get forwardTo => 'Weiterleiten an';
	@override String get forwardToFriend => 'An Freund weiterleiten';
	@override String forwardedToChats({required Object count}) => 'An ${count} Chats weitergeleitet';
	@override String get great => 'Ausgezeichnet';
	@override String get groupFile => 'Gruppendateien';
	@override String get groupFileImagePreview => 'Bildvorschau';
	@override String get groupFileVideoPreview => 'Videovorschau';
	@override String get groupFileAudioPreview => 'Audiovorschau';
	@override String get groupFileMediaPause => 'Pause';
	@override String get groupFileMediaPlay => 'Wiedergabe';
	@override String get groupFileUrlMissing => 'Dateiadresse fehlt, kann nicht geöffnet werden';
	@override String get groupFileUrlInvalid => 'Dateiadresse ungültig';
	@override String get groupFilePreview => 'Dateivorschau';
	@override String get groupFileUnnamed => 'Unbenannte Datei';
	@override String groupFileCategoryEmpty({required Object category}) => '${category}: Keine Dateien';
	@override String get groupFileEmpty => 'Keine Gruppendateien';
	@override String get groupFileCategoryDoc => 'Dokument';
	@override String get groupFileCategoryImage => 'Bild';
	@override String get groupFileCategoryVideo => 'Video';
	@override String get groupFileCategoryAudio => 'Audio';
	@override String get groupFileCategoryOther => 'Sonstiges';
	@override String get groupChat => 'Gruppenchat';
	@override String get image => 'Bild';
	@override String get imageMessage => '[Bild]';
	@override String get initiateChat => 'Gruppenchat starten';
	@override String get exportMyData => 'Meine Daten exportieren';
	@override String get exportDataDesc => 'Persönliche Daten, Kontakte und Chat-Verlauf exportieren';
	@override String get customMessage => 'Benutzerdefinierte Nachricht';
	@override String get card => 'Karte';
	@override String get messageWasWithdrawn => 'hat eine Nachricht zurückgerufen';
	@override String messageWasWithdrawnWithTitle({required Object param}) => '${param} hat eine Nachricht zurückgerufen';
	@override String get offline => 'Offline';
	@override String get online => 'Online';
	@override String paramAlreadyExist({required Object param}) => '${param} existiert bereits';
	@override String get pin => 'Anheften';
	@override String get pinned => 'Angepinnt';
	@override String get rating => 'Bewertung';
	@override String readAgreeParam({required Object param}) => 'Habe gelesen und zugestimmt ${param}';
	@override String get remindMeLater => 'Später erinnern';
	@override String get quickReplyManage => 'Schnellantworten verwalten';
	@override String get quickReplyEmpty => 'Keine Schnellantworten. Unten rechts tippen zum Hinzufügen';
	@override String get quickReplyDuplicate => 'Inhalt existiert bereits';
	@override String quickReplyMaxReached({required Object max}) => 'Max. ${max} Einträge';
	@override String get quickReplyHint => 'Inhalt eingeben...';
	@override String get muteMember => 'Mitglied stummschalten';
	@override String get unmuteMember => 'Stummschaltung aufheben';
	@override String get muted => 'Stummgeschaltet';
	@override String mutedFor({required Object label}) => 'Stummgeschaltet: ${label}';
	@override String muteUnitMinutes({required Object count}) => '${count} Min.';
	@override String muteUnitHours({required Object count}) => '${count} Std.';
	@override String muteUnitDays({required Object count}) => '${count} Tage';
	@override String get youAreMuted => 'Sie wurden stummgeschaltet';
	@override String youAreMutedWithTime({required Object minutes}) => 'Sie sind stummgeschaltet, noch ${minutes} Min.';
	@override String get repliedAt => 'Geantwortet am';
	@override String get reply => 'Antworten';
	@override String get resendCode => 'Code erneut senden';
	@override String get revoke => 'Widerrufen';
	@override String get scanQrCodeBusinessCard => 'QR-Code-Visitenkarte scannen';
	@override String get privateChat => 'Privatchat';
	@override String get sendFriendRequest => 'Freundschaftsanfrage senden';
	@override String get sendMsgRejected => 'Nachricht gesendet, aber vom Gesprächspartner abgelehnt.';
	@override String get sendMessage => 'Nachricht senden';
	@override String get sendTo => 'Senden an';
	@override String get send => _root.common.buttonSend;
	@override String get sending => 'Wird gesendet...';
	@override String get socialProfile => 'Soziales Profil';
	@override String get sureOpenTheFile => 'Datei öffnen?';
	@override String get titleMessage => 'Nachrichten';
	@override String get unpin => 'Anheftung aufheben';
	@override String get userData => 'Benutzerdaten';
	@override String get video => 'Video';
	@override String get videoMessage => '[Video]';
	@override String get viewAttachments => 'Anhänge anzeigen';
	@override String get viewLargeImage => 'Großes Bild ansehen';
	@override String get voice => 'Sprache';
	@override String get voiceMessage => 'Sprachnachricht';
	@override String get youWithdrewAMessage => 'Sie haben eine Nachricht widerrufen';
	@override String get formatCheck => 'Formatprüfung';
	@override String get featureRequest => 'Funktionsanfrage';
	@override String get chatResend => 'Erneut senden';
	@override String get profileExportProfile => 'Profil exportieren';
	@override String get momentsSend => 'Senden';
	@override String get loginExpiredMessage => 'Anmeldung abgelaufen, bitte erneut anmelden';
	@override String get customImage => 'Benutzerdefiniertes Bild';
	@override String get burnAfterReading => 'Nach dem Lesen vernichten';
	@override String get goodReadability => 'Gute Lesbarkeit';
	@override String get profileCompleteness => 'Profil-Vollständigkeit';
	@override String get tagStatistics => 'Tag-Statistik';
	@override String get unsupportedMessageType => 'Nicht unterstützter Nachrichtentyp';
	@override String get passwordMismatch => 'Passwörter stimmen nicht überein';
	@override String get pleaseTryAgainLater => 'Bitte versuchen Sie es später erneut';
	@override String get historyUnavailable => 'Verlaufsnachrichten vorübergehend nicht verfügbar';
	@override String get historyUnavailableHint => 'Serverseitiges Verlaufsarchiv ist deaktiviert oder nicht verfügbar. Tippen Sie auf Erneut versuchen, um die Synchronisierung neu zu starten';
	@override String get momentsRecordVideo => 'Video aufnehmen';
	@override String get momentsVisibilityPrivate => 'Nur ich';
	@override String get momentsMediaTooManyImages => 'Max. 9 Bilder auswählbar';
	@override String get momentsMediaTooManyVideos => 'Max. 1 Video auswählbar';
	@override String get momentsMediaMixedImageAndVideo => 'Bilder und Video nicht gleichzeitig';
	@override String get momentsReplyPrefix => 'Antwort @';
	@override String get momentsReplySeparator => '：';
	@override String get momentsReplyingTo => 'Antwort an @{name}';
	@override String get sendNewMessage => 'Neue Nachricht senden';
	@override String get markRead => 'Als gelesen markieren';
	@override String get markUnread => 'Als ungelesen markieren';
	@override String get manualPendingBadge => 'Ausstehend';
	@override String get cancelManualPending => 'Ausstehend aufheben';
	@override String get manualPendingOff => 'Nicht ausstehend';
	@override String manualPendingConflict({required Object param}) => 'Aktueller Serverstatus: ${param}';
	@override String get pleaseEnterSignature => 'Persönliche Signatur eingeben';
	@override String get exportProfile => 'Profil exportieren';
	@override String get setSignature => 'Signatur festlegen';
	@override String get setAvatar => 'Avatar festlegen';
	@override String fastForward({required Object seconds}) => 'Schnell vor ${seconds} Sekunden';
	@override String get messageId => 'Nachrichten-ID';
	@override String get chatType => 'Chat-Typ';
	@override String get deletingMessage => 'Wird gelöscht...';
	@override String get deletingLocalMessage => 'Lokale Nachricht wird gelöscht...';
	@override String get quickReplyReceived => 'Erhalten';
	@override String get quickReplyThanks => 'Danke';
	@override String get quickReplyWait => 'Einen Moment';
	@override String groupCategoryGroupCount({required Object count}) => '${count} Gruppen';
	@override String get groupAlbumCreateTitle => 'Gruppenalbum erstellen';
	@override String get groupAlbumCreated => 'Album erstellt';
	@override String get profileCompleted => 'Profil vollständig!';
	@override String profileProgress({required Object percent}) => '${percent}% vollständig';
	@override String createdAtLabel({required Object time}) => 'Erstellt: ${time}';
	@override String expiredAtLabel({required Object time}) => 'Gültig bis: ${time}';
	@override String get myReceivedTab => 'Erhalten';
	@override String orderStatusLabel({required Object status}) => 'Status: ${status}';
	@override String orderCreatedAtLabel({required Object time}) => 'Erstellt: ${time}';
	@override String orderPaymentAtLabel({required Object time}) => 'Bezahlt: ${time}';
	@override String get orderStatusPending => 'Offen';
	@override String get orderStatusPaid => 'Bezahlt';
	@override String get orderStatusRefunded => 'Erstattet';
	@override String get orderStatusExpired => 'Abgelaufen';
	@override String get defaultFileName => 'Datei';
	@override String get fileUrlInvalid => 'Dateilink ungültig';
	@override String get e2eeStatusAvailable => 'Verfügbar';
	@override String get e2eeGenerateNewKey => 'Neuen Schlüssel erstellen';
	@override String get e2eeGenerateNewKeyDesc => 'Neues E2EE-Schlüsselpaar erstellen (alte Nachrichten nicht mehr entschlüsselbar)';
	@override String get e2eeActivated => 'Aktiv';
	@override String get e2eeCreatedAtLabel => 'Erstellt am';
	@override String get e2eeGeneratingKey => 'Schlüssel wird erstellt, bitte warten...';
	@override String get e2eeNewKeyGenerated => 'Neues E2EE-Schlüsselpaar erstellt!';
	@override String get webFeatureMultiDevice => 'Multi-Geräte-Sync';
	@override String get webFeatureMultiDeviceDesc => 'Nahtlos zwischen Handy und PC wechseln, Nachrichten in Echtzeit synchronisieren';
	@override String get webFeatureE2EE => 'E2EE';
	@override String get webFeatureE2EEDesc => 'Alle Nachrichten E2EE-verschlüsselt für maximale Privatsphäre';
	@override String get webFeatureFileTransfer => 'Dateiübertragung';
	@override String get webFeatureFileTransferDesc => 'Dateien per Drag & Drop senden, alle Formate';
	@override String get webQRStatusWaiting => 'ImBoy-App öffnen > Einstellungen > Scannen';
	@override String get webQRStatusScanned => 'Am Handy „Anmelden" antippen';
	@override String get webQRStatusVerifying => 'Wird geprüft...';
	@override String get webQRStatusExpired => 'Aktualisieren und erneut scannen';
	@override String get e2eeErrInvalidFormat => 'Ungültiges Nachrichtenformat, Verschlüsselung fehlgeschlagen';
	@override String get e2eeRecreatingKey => 'Schlüssel wird neu erstellt...';
	@override String get e2eeKeyRecreated => 'Schlüssel neu erstellt';
	@override String get e2eeRecoveryNewDeviceTitle => 'Neue Gerätenutzung erkannt';
	@override String get e2eeRecoveryNewDeviceBody => 'Zum Schutz Ihrer Nachrichten wurde auf diesem Gerät ein neuer Ende-zu-Ende-Verschlüsselungsschlüssel erzeugt.\n\nÄltere Nachrichten wurden mit dem Schlüssel des alten Geräts verschlüsselt und sind erst nach Wiederherstellung des Schlüssels sichtbar. Sie können ihn über „Lokales Backup importieren“ wiederherstellen.';
	@override String get e2eeRecoveryDecryptFailedTitle => 'Diese Nachricht kann nicht entschlüsselt werden';
	@override String get e2eeRecoveryDecryptFailedBody => 'Diese Nachricht wurde mit dem Schlüssel eines anderen Geräts verschlüsselt.\n\nWenn Sie das Gerät gewechselt oder die App neu installiert haben, stellen Sie den Schlüssel wieder her, um ältere Nachrichten zu lesen.';
	@override String get e2eeRecoveryLater => 'Später';
	@override String get e2eeRecoveryGoRecover => 'Wiederherstellen';
	@override String get e2eeRecoveryBannerText => 'Verschlüsselte ältere Nachrichten erkannt. Schlüssel zum Anzeigen wiederherstellen. Tippen für Wiederherstellung.';
	@override String get liveRoomCreateTitle => 'Livestream erstellen';
	@override String get liveRoomCreating => 'Wird erstellt...';
	@override String get liveRoomWatch => 'Ansehen';
	@override String get switchToVoiceInput => 'Zur Spracheingabe wechseln';
	@override String get switchToKeyboardInput => 'Zur Tastatureingabe wechseln';
	@override String get extraItems => 'Extras';
	@override String get messageInputHint => 'Nachricht schreiben ...';
	@override String get invalidMessageType => '[Nicht unterstützte Nachricht]';
	@override String get burnReadBadge => 'Selbstlöschend';
	@override String get convertToText => 'In Text umwandeln';
	@override String get releaseConvertToText => 'Loslassen: In Text umwandeln';
	@override String get voiceReleaseCancel => 'Loslassen: Abbrechen';
	@override String get voiceReleaseCancelSend => 'Loslassen: Senden abbrechen';
	@override String get voiceSlideHint => 'Nach oben wischen: Abbrechen / In Text umwandeln';
	@override String get alipayLoginInterrupted => 'Alipay-Anmeldung vom System unterbrochen, bitte erneut versuchen';
	@override String get encryptedMessagePlaceholder => '[Verschlüsselte Nachricht]';
	@override String get e2eeDecryptStoreUnavailable => 'Der verschlüsselte Speicher ist vorübergehend nicht zugänglich; diese Nachricht konnte nicht entschlüsselt werden. Bitte starten Sie die App neu und versuchen Sie es erneut';
	@override String get invalidMessagePlaceholder => '[Ungültige Nachricht]';
	@override String get videoCallPlaceholder => '[Videoanruf]';
	@override String get voiceCallPlaceholder => '[Sprachanruf]';
	@override String get notFriendCannotSend => 'Keine Freundschaft, Senden nicht möglich';
}

// Path: common
class _Translations$common$de_DE extends Translations$common$zh_CN {
	_Translations$common$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get about => 'Über';
	@override String get aboutApp => 'Über die App';
	@override String get accept => 'Akzeptieren';
	@override String get acceptFriendRequest => 'Freundschaftsanfrage bestätigen';
	@override String get addFriend => 'Freund hinzufügen';
	@override String get dataNotFound => 'Die Daten dieser Seite fehlen oder sind abgelaufen';
	@override String get smallChange => 'Kleingeld';
	@override String get addTag => 'Tag hinzufügen';
	@override String get addToContacts => 'Zu Kontakten hinzufügen';
	@override String get addToDenylist => 'Zur Sperrliste hinzufügen';
	@override String get added => 'Hinzugefügt';
	@override String get addedToDenylistTips => 'Zur Sperrliste hinzugefügt. Sie erhalten keine Nachrichten mehr von dieser Person.';
	@override String get all => 'Alle';
	@override String get allTime => 'Gesamter Zeitraum';
	@override String get allTypes => 'Alle Typen';
	@override String get allowSearchMe => 'Suche nach mir erlauben';
	@override String get allowedBeSearched => 'Kürzlich registrierte Freunde, die gefunden werden dürfen';
	@override String get appSizeTips => 'Erforderliche App-Dateien: APK, Compiler-Ausgabe, native Bibliotheken.';
	@override String get applyAddFriend => 'Freund hinzufügen beantragen';
	@override String get awaitingVerification => 'Warten auf Bestätigung';
	@override String get buttonAccomplish => 'Fertig';
	@override String get buttonAdd => 'Hinzufügen';
	@override String get buttonBack => 'Zurück';
	@override String get bindMobileAndEmailTips => 'Verbinden Sie Ihre Mobilfunknummer und E-Mail, um Ihr Konto sicherer zu machen';
	@override String get bindNow => 'Jetzt verbinden';
	@override String get buttonCancel => 'Abbrechen';
	@override String get buttonCreate => 'Erstellen';
	@override String get phoneInputHint => 'Telefonnummer eingeben';
	@override String get buttonMore => 'Mehr';
	@override String get buttonRefresh => 'Aktualisieren';
	@override String get buttonClose => 'Schließen';
	@override String get buttonConfirm => 'Bestätigen';
	@override String get buttonContinue => 'Fortfahren';
	@override String get buttonCopy => 'Kopieren';
	@override String get buttonDelete => 'Löschen';
	@override String get buttonLogout => 'Abmelden';
	@override String get buttonOk => 'OK';
	@override String get buttonRetry => 'Wiederholen';
	@override String get buttonSave => 'Speichern';
	@override String get buttonSelectFromAlbum => 'Aus Album auswählen';
	@override String get buttonSend => 'Senden';
	@override String get buttonTakingPictures => 'Foto aufnehmen';
	@override String get cacheTips => 'Temporäre App-Daten. Bereinigung beeinflusst Nutzung nicht.';
	@override String get callDuration => 'Anrufdauer';
	@override String get callEnded => 'Anruf beendet';
	@override String get calling => 'Im Gespräch';
	@override String get cancel => _root.common.buttonCancel;
	@override String get ok => _root.common.buttonOk;
	@override String get operationSuccessful => 'Erfolgreich';
	@override String get save => _root.common.buttonSave;
	@override String get reset => 'Zurücksetzen';
	@override String get clear => 'Leeren';
	@override String saveTag({required Object count}) => 'Tags speichern (${count})';
	@override String get cancelLogoutBody => 'Konto in Widerrufsfrist. Anmeldung = Löschung stornieren. Für Löschung: 15 Tage nach Antrag nicht anmelden.';
	@override String get cancelLogoutTitle => 'Löschvorgang abbrechen?';
	@override String get cancelled => 'Abgebrochen';
	@override String get chatSettingBackground => 'Chat-Hintergrund';
	@override String get chatSettingPinnedSuccess => 'Erfolgreich angepinnt';
	@override String get chatSettingUnpinnedSuccess => 'Anheftung aufgehoben';
	@override String get chatSettings => 'Chat-Einstellungen';
	@override String get chatStatusFailed => 'Fehlgeschlagen';
	@override String get chatErrorInDenylist => 'Sie stehen auf der Sperrliste';
	@override String get checkForUpdates => 'Auf Updates prüfen';
	@override String get clearAll => 'Alle entfernen';
	@override String get clearChatRecord => 'Chat-Verlauf leeren';
	@override String get complaintSuccess => 'Meldung gesendet';
	@override String get complaintFailed => 'Meldung fehlgeschlagen. Bitte später erneut versuchen.';
	@override String get confirmDeleteChatRecord => 'Chat-Verlauf löschen?';
	@override String get confirmRecoverSuccess => 'Passwort erfolgreich geändert.';
	@override String get contactSetting => 'Kontakteinstellungen';
	@override String get contactTags => 'Kontakt-Tags';
	@override String get contactInfoNotSynced => 'Kontaktinformationen nicht synchronisiert';
	@override String get continueDownloading => 'Download fortsetzen';
	@override String get copy => 'Kopieren';
	@override String get createGroupF2fConfirmTips => 'Diese Freunde treten ebenfalls den Gruppenchat bei';
	@override String get createGroupF2fTips => 'Geben Sie dieselben vier Ziffern wie Freunde in Ihrer Nähe ein, um denselben Gruppenchat beizutreten';
	@override String get delete => _root.common.buttonDelete;
	@override String get deleteCollectConfirmDesc => 'Nach dem Löschen kann nicht wiederhergestellt werden. Möchten Sie diesen Favoriten wirklich löschen?';
	@override String get deleteContact => 'Kontakt löschen';
	@override String get deleteForEveryone => 'Für alle löschen';
	@override String get deleteForMe => 'Für mich löschen';
	@override String get deleteTagTips => 'Nach dem Löschen des Tags werden die Kontakte im Tag nicht gelöscht';
	@override String get deleteThisDevice => 'Dieses Gerät löschen';
	@override String get deleteThisDeviceTips => 'Nach Löschen ist bei nächster Anmeldung auf diesem Gerät eine Sicherheitsüberprüfung erforderlich.';
	@override String get denylistNoteDesc => 'Blockierte Benutzer können Ihnen keine Nachrichten senden und Ihre Beiträge nicht sehen. Tippen Sie auf den Benutzer, um Details anzuzeigen.';
	@override String get denylistNoteTitle => 'Erklärung zur Sperrliste';
	@override String get details => 'Details';
	@override String get deviceDetails => 'Gerätedetails';
	@override String get downloaded => 'Heruntergeladen';
	@override String get edit => 'Bearbeiten';
	@override String get editTag => 'Tag bearbeiten';
	@override String errorEmptyDirectory({required Object param}) => '${param} ist leer';
	@override String get errorFailedConnectServer => _root.common.error;
	@override String get errorHttpNotSupported => _root.common.error;
	@override String get errorInternalServer => _root.common.error;
	@override String errorInvalid({required Object param}) => '${param} ist ungültig';
	@override String get errorInvalidRequest => _root.common.error;
	@override String errorLengthBetween({required Object param, required Object min, required Object max}) => 'Die Länge von ${param} muss zwischen ${min} und ${max} liegen';
	@override String get errorManyRequest => _root.common.error;
	@override String get errorPassword => 'Falsches Passwort';
	@override String get errorRequestForbidden => _root.common.error;
	@override String get errorRequestSyntax => _root.common.error;
	@override String errorRequired({required Object param}) => '${param} ist erforderlich';
	@override String get errorRetypePassword => _root.common.error;
	@override String get errorServerDown => _root.common.error;
	@override String get errorServerRefused => _root.common.error;
	@override String get errorUnexpected => _root.common.error;
	@override String get failedGetLatLong => _root.common.errorNetwork;
	@override String get failedGetMapTryAgain => _root.common.errorNetwork;
	@override String get failedRequestPleaseCheckNetwork => _root.common.errorNetwork;
	@override String get feedback => 'Feedback und Vorschläge';
	@override String get feedbackContentRequired => 'Feedback-Inhalt darf nicht leer sein';
	@override String get feedbackDetails => 'Feedback-Details';
	@override String get feedbackSuccessMsg => 'Feedback erhalten. Wir werden es schnell bearbeiten!';
	@override String get followSystemTips => 'Nach Aktivierung wird der Dunkel-Modus entsprechend dem System ein- oder ausgeschaltet';
	@override String get genderUpdateFailed => 'Geschlechtseinstellung fehlgeschlagen, bitte versuchen Sie es erneut';
	@override String get groupAnnouncement => 'Gruppenankündigung';
	@override String get groupFileUploadSuccess => 'Datei hochgeladen';
	@override String get groupFileUploadFailed => 'Upload fehlgeschlagen. Bitte später erneut versuchen.';
	@override String get groupFileDeleteSuccess => 'Datei gelöscht';
	@override String get groupFileDeleteFailed => 'Löschen fehlgeschlagen. Bitte später erneut versuchen.';
	@override String get groupFileUploadTooltip => 'Datei hochladen';
	@override String get groupFileSearch => 'Gruppendateien durchsuchen';
	@override String get groupFileReadFailed => 'Datei konnte nicht gelesen werden. Bitte erneut versuchen.';
	@override String get groupFileDeleteTitle => 'Gruppendatei löschen';
	@override String groupFileDeleteConfirm({required Object name}) => 'Datei „${name}" wirklich löschen?';
	@override String get groupFileImageLoadFailed => 'Bild konnte nicht geladen werden';
	@override String get groupFileOpenFailed => 'Dateilink kann nicht geöffnet werden';
	@override String get groupFileCategoryAll => 'Alle';
	@override String get groupFileSearchEmpty => 'Keine passenden Dateien gefunden';
	@override String get groupFileAudioLoadFailed => 'Audio konnte nicht geladen werden';
	@override String get groupFileAudioLoading => 'Audio wird geladen...';
	@override String groupQrcodeTips({required Object days, required Object date}) => 'Dieser QR-Code ist ${days} Tage gültig (bis ${date}), wird beim erneuten Betreten aktualisiert';
	@override String get helpDocument => 'Hilfe-Dokument';
	@override String incomingCall({required Object param}) => '${param} ruft an';
	@override String get installNow => 'Jetzt installieren';
	@override String iosAppIdUnknown({required Object param}) => 'AppStore nicht gelistet oder AppID [${param}] existiert nicht';
	@override String get koKr => 'Koreanisch (Südkorea)';
	@override String get languageSetting => 'Spracheinstellung';
	@override String get lastActiveTips => 'Bei sicherem Gerät wird die Anmeldezeit automatisch verlängert, um Freundenachrichten-Empfang/-Versand aufrechtzuerhalten. Die letzte Aktivitätszeit wird aktualisiert.';
	@override String get lastSeenJustNow => 'Gerade online';
	@override String get lastSeenLongTimeAgo => 'Vor langer Zeit online';
	@override String lastSeenMonthsAgo({required Object param}) => 'Vor ${param} Monaten';
	@override String get loadError => 'Laden fehlgeschlagen, bitte versuchen Sie es erneut';
	@override String get loadMore => 'Mehr laden';
	@override String get loading => 'Wird geladen';
	@override String get locationMessage => 'Standortnachricht';
	@override String get loginDeviceManagementTips => 'Konto auf folgenden Geräten angemeldet. Sie können Geräte löschen. Nach Löschen ist bei nächster Anmeldung auf diesem Gerät eine Sicherheitsüberprüfung erforderlich.';
	@override String get logoutFailed => 'Abmelden fehlgeschlagen';
	@override String get messageCall => 'Nachricht senden';
	@override String get messageContent => 'Nachrichteninhalt';
	@override String get messageRevoked => 'Nachricht zurückgerufen';
	@override String get quoteMessageNotAvailable => 'Referenzierte Nachricht nicht verfügbar';
	@override String get microphone => 'Mikrofon';
	@override String get microphonePermissionNotObtained => 'Mikrofonberechtigung nicht erteilt';
	@override String get moreInfo => 'Mehr Infos';
	@override String get nearbyPeopleTips => 'Kontaktdaten mit Personen in der Nähe austauschen und neue Freunde kennenlernen';
	@override String get needContinueWorkHard => 'Weiter hart arbeiten';
	@override String networkErrorWithAction({required Object param}) => '${param} fehlgeschlagen, bitte überprüfen Sie Ihre Netzwerkverbindung';
	@override String get networkException => 'Netzwerkverbindungsfehler';
	@override String get errorNetwork => 'Netzwerkfehler';
	@override String get networkExceptionPlaseNeedNetworkToViewData => 'Netzwerkstatus abnormal, Netzwerkverbindung erforderlich, um Daten anzuzeigen';
	@override String get newVersionDetected => 'Neue Version erkannt';
	@override String newVersionDetectedWithVersion({required Object param}) => 'Neue Version erkannt ${param}';
	@override String get nextStep => 'Nächster Schritt';
	@override String get nicknameEmojiOnlyError => 'Spitzname darf nicht nur aus Emojis bestehen';
	@override String get nicknameEmptyError => 'Spitzname darf nicht leer sein';
	@override String get nicknameLengthError => 'Spitznamenlänge sollte zwischen 2-24 Zeichen liegen';
	@override String get nicknameSensitiveWordError => 'Spitzname enthält sensible Wörter, bitte erneut eingeben';
	@override String get nicknameUpdateFailed => 'Spitzname ändern fehlgeschlagen, bitte versuchen Sie es erneut';
	@override String get nicknameWhitespaceError => 'Spitzname darf nicht nur aus Leerzeichen bestehen';
	@override String get noAvatar => 'Kein Avatar';
	@override String get noBarcodeFound => 'Strichcode nicht gefunden!';
	@override String get noContacts => 'Keine Kontakte';
	@override String get noConversationMessages => 'Keine Nachrichten';
	@override String get noData => 'Keine Daten';
	@override String get noMembersInCurrentTag => 'Keine Mitglieder im aktuellen Tag';
	@override String get noNewFriends => 'Keine neuen Freunde';
	@override String get noPermission => 'Keine Berechtigung';
	@override String get noReply => 'Keine Antwort';
	@override String get noUpdateDescription => 'Keine Update-Beschreibung';
	@override String get notAuthorizedLatLong => 'Berechtigung für Standortabfrage noch nicht erteilt';
	@override String get notLoggedIn => 'Nicht angemeldet';
	@override String get notBad => 'Nicht schlecht';
	@override String get notBound => 'Nicht gebunden';
	@override String get notFilled => 'Nicht ausgefüllt';
	@override String get notInstallAnyMapApp => 'Sie haben keine Karten-App installiert';
	@override String get notReceiveCoeQ => 'Keinen Bestätigungscode erhalten?';
	@override String get notSet => 'Nicht eingestellt';
	@override String get notTurnedLocationService => 'Sie haben den Standortdienst noch nicht aktiviert';
	@override String get nowNewVersion => 'Keine neue Version erkannt';
	@override String get offlineNotification => 'Offline-Benachrichtigung';
	@override String get operationFailedAgainLater => 'Operation fehlgeschlagen, bitte versuchen Sie es später erneut';
	@override String get pauseDownloading => 'Download pausieren';
	@override String get peerNoResponse => 'Gesprächspartner antwortet nicht...';
	@override String get permissionAcquisitionFailed => 'Berechtigung konnte nicht erteilt werden';
	@override String get personalCard => 'Persönliche Visitenkarte';
	@override String get personalInformation => 'Persönliche Informationen';
	@override String get pinCodeFillTips => 'Bitte füllen Sie alle Felder aus';
	@override String get profileSettings => 'Profil-Einstellungen';
	@override String get reEdit => 'Erneut bearbeiten';
	@override String get regionSearchHint => 'Nach Regionsname suchen';
	@override String regionSelectedLevelHint({required Object region, required Object level}) => 'Ausgewählt: ${region} (Ebene ${level}). Sie können jetzt fertigstellen oder weiter eingrenzen.';
	@override String get releaseFingerCancelSending => 'Finger nach oben wischen, um das Senden abzubrechen';
	@override String get removeContactFromTag => 'Kontakt aus Tag entfernen';
	@override String get removeMember => 'Mitglied entfernen';
	@override String get atMentionYouTag => '[@dir] ';
	@override String get atMentionLeftMember => '@ausgetretenes Mitglied';
	@override String get muteNotifications => 'Benachrichtigungen stummschalten';
	@override String get muteNotificationsHint => 'Bei Aktivierung erhalten Sie keine Benachrichtigungen, sehen aber ungelesene Nachrichten in der Chat-Liste';
	@override String get revokeExpired => 'Mehr als 2 Minuten, Widerruf nicht möglich';
	@override String get quickReplyAddTitle => 'Schnellantwort hinzufügen';
	@override String get quickReplyEditTitle => 'Schnellantwort bearbeiten';
	@override String get removeAdmin => 'Admin entfernen';
	@override String get setAdminConfirm => 'Dieses Mitglied als Admin festlegen?';
	@override String get removeAdminConfirm => 'Admin-Rolle dieses Mitglieds entziehen?';
	@override String get unmuteMemberConfirm => 'Stummschaltung dieses Mitglieds aufheben?';
	@override String get kickMemberConfirm => 'Dieses Mitglied aus der Gruppe entfernen?';
	@override String get setAdminSuccess => 'Admin festgelegt';
	@override String get setAdminFailed => 'Admin konnte nicht festgelegt werden';
	@override String get removeAdminSuccess => 'Admin entfernt';
	@override String get removeAdminFailed => 'Admin konnte nicht entfernt werden';
	@override String get muteMemberSuccess => 'Mitglied stummgeschaltet';
	@override String get muteMemberFailed => 'Stummschalten fehlgeschlagen';
	@override String get unmuteMemberSuccess => 'Stummschaltung aufgehoben';
	@override String get unmuteMemberFailed => 'Aufheben der Stummschaltung fehlgeschlagen';
	@override String get kickMemberSuccess => 'Mitglied entfernt';
	@override String get kickMemberFailed => 'Mitglied konnte nicht entfernt werden';
	@override String get notMuted => 'Nicht stummgeschaltet';
	@override String get muteDuration => 'Stummschaltungsdauer';
	@override String get muteDuration1hour => '1 Stunde';
	@override String get muteDuration1day => '1 Tag';
	@override String get muteDuration7days => '7 Tage';
	@override String get muteDuration5min => '5 Min.';
	@override String get muteDuration10min => '10 Min.';
	@override String get muteDuration30min => '30 Min.';
	@override String get muteDuration30days => '30 Tage';
	@override String muteUnitSeconds({required Object count}) => '${count} Sek.';
	@override String get throttleWarning => 'Zu viele Aktionen. Bitte später erneut versuchen.';
	@override String throttleRetryAfter({required Object seconds}) => 'Zu viele Aktionen. Bitte in ${seconds} Sek. erneut versuchen.';
	@override String get mutedCannotSend => 'Während Stummschaltung können keine Nachrichten gesendet werden';
	@override String get resetFilters => 'Filter zurücksetzen';
	@override String get saveQrCode => 'QR-Code speichern';
	@override String get saveSuccess => 'Erfolgreich gespeichert';
	@override String get scanQrcodeAddFriend => 'Scannen Sie den QR-Code, um mich als Freund hinzuzufügen';
	@override String get search => 'Suche';
	@override String get searchScope => 'Suchbereich';
	@override String get searchAll => 'Alle Nachrichten';
	@override String get searchChatContent => 'Chat-Inhalt durchsuchen';
	@override String get searchChatRecord => 'Chat-Verlauf durchsuchen';
	@override String get searchError => 'Suchfehler';
	@override String get searchHint => 'Schlüsselwörter eingeben, um Nachrichten zu suchen';
	@override String get searchHistory => 'Suchverlauf';
	@override String get searchLocation => 'Standort suchen';
	@override String get searchMessagesHint => 'Chat-Inhalt durchsuchen';
	@override String get searchNoFound => 'Keine Suchergebnisse :(';
	@override String get searchNoResults => 'Keine Suchergebnisse';
	@override String get noSearchHistory => 'Kein Suchverlauf';
	@override String get searchResults => 'Suchergebnisse';
	@override String get selectAll => 'Alle auswählen';
	@override String get selectContacts => 'Kontakte auswählen';
	@override String get selectedRegion => 'Ausgewählte Region';
	@override String get sendMsgNotFriendTips => 'Gesprächspartner hat Freundesverifizierung aktiviert. Sie sind noch nicht Freund. Senden Sie zuerst eine Freundesanfrage. Nach Bestätigung können Sie chatten.';
	@override String get share => 'Teilen';
	@override String get slideUpCancelSending => 'Finger nach oben wischen, um das Senden abzubrechen';
	@override String get storagePermissionNotObtained => 'Speicherberechtigung nicht erteilt';
	@override String get submittedAt => 'Eingereicht am';
	@override String get sureDeleteData => 'Löschen bestätigen? Nach dem Löschen kann nicht wiederhergestellt werden.';
	@override String get sureDeleteGroupChatRecord => 'Chat-Verlauf der Gruppe löschen?';
	@override String get switchEnvironment => 'Umgebung wechseln';
	@override String timeDaysAgo({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(n,
		one: 'Vor ${n} Tag',
		other: 'Vor ${n} Tagen',
	);
	@override String timeHoursAgo({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(n,
		one: 'Vor ${n} Stunde',
		other: 'Vor ${n} Stunden',
	);
	@override String get timeJustNow => 'Gerade eben';
	@override String timeMinutesAgo({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(n,
		one: 'Vor ${n} Minute',
		other: 'Vor ${n} Minuten',
	);
	@override String get tipConnectDesc => 'Kein Netzwerk';
	@override String tipConnectDescWithParen({required Object param}) => '(${param})';
	@override String tipDeleteContact({required Object param}) => 'Kontakt "${param}" löschen, gleichzeitig den Chat-Verlauf mit diesem Kontakt löschen';
	@override String tipDeviceSpace({required Object param1, required Object param2}) => 'Belegt ${param1}% des Gerätespeichers(${param2})';
	@override String get tipDraft => 'Entwurf';
	@override String get tipFailed => 'Operation fehlgeschlagen!';
	@override String get tipSuccess => 'Operation erfolgreich!';
	@override String get tipTips => 'Tipps';
	@override String get titleContact => 'Kontakte';
	@override String get today => 'Heute';
	@override String get unknown => 'Unbekannt';
	@override String get unknownMessage => 'Unbekannte Nachricht';
	@override String get updateLog => 'Update-Protokoll';
	@override String get updateNow => 'Jetzt aktualisieren';
	@override String get uploading => 'Wird hochgeladen…';
	@override String get uploadSuccess => 'Hochgeladen';
	@override String get uploadFailed => 'Hochladen fehlgeschlagen';
	@override String get userDataTips => 'Enthält notwendige App-Dateien sowie alle Daten wie Chatnachrichten und Kontakte.';
	@override String get userDisabledOrDeleted => 'Benutzer deaktiviert oder gelöscht';
	@override String get userNotExist => 'Benutzer existiert nicht';
	@override String get version => 'Version';
	@override String get videoCall => 'Videoanruf';
	@override String get viewAllGroupMember => 'Alle Gruppenmitglieder anzeigen';
	@override String get voiceCall => 'Sprachanruf';
	@override String get groupCall => 'Gruppenanruf';
	@override String get callDisconnected => 'Anruf getrennt';
	@override String get connecting => 'Verbinden…';
	@override String get voiceInputNotImplemented => 'Spracheingabe-Funktion noch nicht implementiert';
	@override String get waitingDownload => 'Warten auf Download';
	@override String get waitingPeerAccept => 'Warten auf Annahme durch den Gesprächspartner...';
	@override String get warning => 'Warnung:';
	@override String get webpageLoading => 'Webseite wird geladen...';
	@override String get yesterday => 'Gestern';
	@override String get confirmRemoveFromDenylist => 'Diesen Benutzer wirklich aus der Sperrliste entfernen?';
	@override String get buttonRemove => 'Entfernen';
	@override String get removedFromDenylist => 'Aus der Sperrliste entfernt';
	@override String get newEmailAddress => 'Neue E-Mail-Adresse';
	@override String get emailAddress => 'E-Mail-Adresse';
	@override String get enterEmailAddress => 'E-Mail-Adresse eingeben';
	@override String get getVerificationCode => 'Bestätigungscode erhalten';
	@override String get confirmChange => 'Änderung bestätigen';
	@override String get verificationCodeSentToEmail => 'Bestätigungscode an diese E-Mail gesendet, bitte innerhalb Gültigkeitsdauer bestätigen';
	@override String get verificationCodeSentToMobile => 'Bestätigungscode an diese Mobilfunknummer gesendet, bitte innerhalb Gültigkeitsdauer bestätigen';
	@override String get sendFailed => 'Senden fehlgeschlagen';
	@override String get forceOffline => 'Abmelden';
	@override String get forceDeviceOffline => 'Gerät offline nehmen';
	@override String get forceDeviceOfflineConfirm => 'Offline-Befehl an dieses Gerät senden, fortfahren?';
	@override String get confirmForceOffline => 'Abmelden bestätigen';
	@override String get forceOfflineCommandSent => 'Offline-Befehl gesendet';
	@override String get feedbackSlogan => 'Ihre Vorschläge sind unser Antrieb für Verbesserungen';
	@override String get newFeedback => 'Neues Feedback';
	@override String get feedbackHistory => 'Feedback-Verlauf';
	@override String get confirmDelete => 'Löschen bestätigen';
	@override String get verificationCode => 'Bestätigungscode';
	@override String get feedbackContent => 'Feedback-Inhalt';
	@override String get officialReply => 'Offizielle Antwort';
	@override String get setPasswordSecurityTips => 'Verbessern Sie die Kontosicherheit und vermeiden Sie Anmeldeprobleme ohne Bestätigungscode. Legen Sie ein Anmeldepasswort fest.';
	@override String get locationHidden => 'Ihr Standort ist ausgeblendet';
	@override String get locationVisible => 'Ihr Standort wird angezeigt';
	@override String get noNearbyPeople => 'Keine Personen in der Nähe';
	@override String get clickSearchButtonToFind => 'Tippen Sie oben auf Suchen, um Personen in der Nähe zu finden';
	@override String get operationFailed => _root.common.error;
	@override String get featureInDevelopment => 'Funktion in Entwicklung...';
	@override String get addedToDenylist => 'Zur Sperrliste hinzugefügt';
	@override String get groupAnnouncementPublish => 'Ankündigung veröffentlichen';
	@override String get pleaseEnterAnnouncementContent => 'Bitte Ankündigungsinhalt eingeben';
	@override String get selectExpirationDateOptional => 'Ablaufdatum auswählen (optional)';
	@override String get groupAnnouncementDeleteConfirm => 'Diese Ankündigung wirklich löschen?';
	@override String get groupAnnouncementDelete => 'Löschen';
	@override String get groupAnnouncementLoadFailed => 'Ankündigung konnte nicht geladen werden. Bitte später erneut versuchen.';
	@override String get groupAnnouncementPublishFailed => 'Ankündigung konnte nicht veröffentlicht werden';
	@override String get groupAnnouncementPublishSuccess => 'Ankündigung veröffentlicht';
	@override String get groupAnnouncementDeleteFailed => 'Ankündigung konnte nicht gelöscht werden';
	@override String get groupAnnouncementDeleteSuccess => 'Ankündigung gelöscht';
	@override String get privacyClearChatHistory => 'Chat-Verlauf löschen';
	@override String get privacyClearChatHistoryConfirm => 'Wirklich gesamten Chat-Verlauf löschen? Diese Aktion kann nicht rückgängig gemacht werden.';
	@override String get privacyLogoutAccountConfirm => 'Konto wirklich löschen? Diese Aktion wird Ihr Konto und alle Daten dauerhaft löschen und kann nicht rückgängig gemacht werden.';
	@override String get privacySettings => 'Datenschutz-Einstellungen';
	@override String get searchSettings => 'Sucheinstellungen';
	@override String get allowSearchByAccount => 'Suche nach Konto erlauben';
	@override String get allowSearchByAccountDesc => 'Andere Benutzer können Sie über Ihr Konto finden';
	@override String get allowAddByPhone => 'Über Mobilfunknummer hinzufügen erlauben';
	@override String get allowAddByPhoneDesc => 'Andere Benutzer können Sie über Ihre Mobilfunknummer als Freund hinzufügen';
	@override String get allowAddByQR => 'Über QR-Code hinzufügen erlauben';
	@override String get allowAddByQRDesc => 'Andere Benutzer können Sie durch Scannen Ihres QR-Codes als Freund hinzufügen';
	@override String get statusSettings => 'Status-Einstellungen';
	@override String get showOnlineStatus => 'Online-Status anzeigen';
	@override String get showOnlineStatusDesc => 'Wenn deaktiviert, können Freunde Ihren Online-Status und Ihre letzte Anmeldezeit nicht sehen; die Nachrichtenzustellung ist nicht beeinträchtigt';
	@override String get allowNearbyVisible => 'Für Personen in der Nähe sichtbar';
	@override String get dataSettings => 'Daten-Einstellungen';
	@override String get clearChatRecords => 'Chat-Verläufe löschen';
	@override String get clearChatRecordsDesc => 'Alle Chat-Verläufe löschen, diese Aktion kann nicht rückgängig gemacht werden';
	@override String get deleteAccountAction => 'Konto löschen';
	@override String get deleteAccountActionDesc => 'Konto und alle Daten dauerhaft löschen, diese Aktion kann nicht rückgängig gemacht werden';
	@override String get chatHistoryCleared => 'Chat-Verlauf gelöscht';
	@override String get chatDeleteMessage => 'Nachricht löschen';
	@override String get chatCopy => 'Kopieren';
	@override String get chatSaveImage => 'Bild speichern';
	@override String get chatDeleteLocalOnly => 'Nur lokal löschen';
	@override String get chatDeleteFailed => 'Löschen fehlgeschlagen';
	@override String get chatNetworkErrorDeleteLocal => 'Netzwerkverbindung fehlgeschlagen, nur lokale Nachricht löschen?';
	@override String get chatDeleteConfirm => 'Diese Nachricht wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.';
	@override String get chatDeleteOnlyLocal => 'Nur für Sie löschen, für andere weiterhin sichtbar';
	@override String get chatDeleteAll => 'Für alle löschen, kann nicht rückgängig gemacht werden';
	@override String get chatInitFailed => 'Chat-Initialisierung fehlgeschlagen';
	@override String get cameraShootFailed => 'Aufnahme fehlgeschlagen';
	@override String get cameraCapture => 'Kamera';
	@override String get cameraModePhoto => 'Foto';
	@override String get cameraModeVideo => 'Video';
	@override String get cameraRetake => 'Neu aufnehmen';
	@override String get cameraUse => 'Verwenden';
	@override String get cameraNoDevice => 'Keine Kamera verfügbar';
	@override String get avatarEditAvatar => 'Avatar bearbeiten';
	@override String get backgroundUseCustomColor => 'Benutzerdefinierte Farbe verwenden';
	@override String get backgroundOnlySolidColor => 'Gilt nur für einfarbige Hintergründe';
	@override String get backgroundSelectColor => 'Farbe auswählen';
	@override String get profileShareProfile => 'Profil teilen';
	@override String get tagClearAllConfirm => 'Wirklich alle Tags leeren?';
	@override String get tagClearAll => 'Leeren bestätigen';
	@override String get audioPlayFailed => 'Wiedergabe fehlgeschlagen';
	@override String forcedOfflineByDevice({required Object device}) => 'Sie wurden vom Gerät [${device}] zwangsabgemeldet';
	@override String get loadingTagDataFailed => 'Laden der Tag-Daten fehlgeschlagen';
	@override String get pleaseEnterContent => 'Bitte Inhalt eingeben';
	@override String get comingSoon => 'Demnächst verfügbar';
	@override String get backgroundTransparency => 'Hintergrundtransparenz';
	@override String get defaultBackground => 'Standardhintergrund';
	@override String get solidColorBackground => 'Einfarbiger Hintergrund';
	@override String get selectImageFailed => 'Bildauswahl fehlgeschlagen';
	@override String get locationSelectNotImplemented => 'Standortauswahl-Funktion noch nicht implementiert';
	@override String get selectLocationFailed => 'Standortauswahl fehlgeschlagen';
	@override String get sendCardNotImplemented => 'Kartensendefunktion noch nicht implementiert';
	@override String get voiceSendFailed => 'Sprachnachricht senden fehlgeschlagen';
	@override String get featureNotImplemented => 'Funktion noch nicht implementiert';
	@override String get sendCollectionNotImplemented => 'Sammlungssendefunktion noch nicht implementiert';
	@override String get fileOpenNotImplemented => 'Dateiöffnungsfunktion noch nicht implementiert';
	@override String get fileShareNotImplemented => 'Dateiteilungsfunktion noch nicht implementiert';
	@override String get retrySuccess => 'Wiederholung erfolgreich';
	@override String get deleteSuccess => 'Erfolgreich gelöscht';
	@override String get localDeleteSuccess => 'Lokales Löschen erfolgreich';
	@override String get localDeleteFailed => 'Lokales Löschen fehlgeschlagen';
	@override String get revokeSuccess => 'Erfolgreich widerrufen';
	@override String get editContentCannotBeEmpty => 'Bearbeitungsinhalt darf nicht leer sein';
	@override String get editSuccess => 'Erfolgreich bearbeitet';
	@override String get enabled => 'Aktiviert';
	@override String get disabled => 'Deaktiviert';
	@override String get fontSizeSettingUpdated => 'Schriftgröße-Einstellung aktualisiert';
	@override String get fontSizeSetting => 'Schriftgröße-Einstellung';
	@override String get fontTooSmallMayAffect => 'Schrift zu klein, kann das Lesen beeinträchtigen';
	@override String get dragSliderAdjustFontSize => 'Schieberegler ziehen, um Schriftgröße anzupassen';
	@override String get personalInfo => 'Persönliche Informationen';
	@override String get nicknameNotSet => 'Spitzname nicht festgelegt';
	@override String get basicInfo => 'Grundlegende Informationen';
	@override String get contactInfo => 'Kontaktinformationen';
	@override String get editTags => 'Tags bearbeiten';
	@override String get quickActions => 'Schnellaktionen';
	@override String get noNewFriendRequests => 'Derzeit keine neuen Freundschaftsanfragen';
	@override String get pleaseEnterVerificationMessage => 'Bitte Bestätigungsnachricht eingeben';
	@override String get unknownRegion => 'Unbekannte Region';
	@override String get noCommonGroups => 'Keine gemeinsamen Gruppen';
	@override String get noMoreInfo => 'Keine weiteren Informationen';
	@override String get verificationMessage => 'Bestätigungsnachricht';
	@override String burnEnabledMessage({required Object duration}) => 'Nach Aktivierung: Nachrichten werden ${duration} nach dem Lesen automatisch zerstört';
	@override String get burnDisabledMessage => 'Nach Deaktivierung: Nachrichten werden nicht automatisch zerstört';
	@override String get noGroupAnnouncement => 'Keine Gruppenankündigung';
	@override String get featureComingSoon => 'Funktion demnächst verfügbar';
	@override String get understood => 'Verstanden';
	@override String get noProblem => 'Kein Problem';
	@override String get onMyWay => 'Bin unterwegs';
	@override String get operationOptions => 'Optionen';
	@override String get copyTextContent => 'Textinhalt kopieren';
	@override String get shareWithOtherFriends => 'Mit anderen Freunden teilen';
	@override String get addTagsToFavorites => 'Tags zu Favoriten hinzufügen';
	@override String get addRemarkToFavorites => 'Bemerkung zu Favoriten hinzufügen';
	@override String get deleteThisCollection => 'Diese Sammlung löschen';
	@override String get changeSuccess => 'Erfolgreich geändert';
	@override String get lengthOk => 'Länge in Ordnung';
	@override String get confirmNewPassword => 'Neues Passwort bestätigen';
	@override String get validationPassed => 'Validierung bestanden';
	@override String get momentsContentHint => 'Etwas schreiben...';
	@override String get momentsAddMedia => 'Medien hinzufügen';
	@override String get momentsAllowUidsLabel => 'Sichtbar für UIDs (kommagetrennt)';
	@override String get momentsNoData => 'Keine Momente';
	@override String get momentsDeleteConfirm => 'Diesen Moment wirklich löschen?';
	@override String get momentsDeleteCommentConfirm => 'Diesen Kommentar wirklich löschen?';
	@override String get momentsNotFound => 'Moment existiert nicht oder keine Berechtigung';
	@override String get momentsContentOrMediaRequired => 'Inhalt oder Medien angeben';
	@override String get momentsPublishFailed => 'Veröffentlichung fehlgeschlagen';
	@override String get momentsAllowComment => 'Kommentare erlauben';
	@override String get momentsNoComments => 'Keine Kommentare';
	@override String get momentsCommentFailed => 'Kommentar fehlgeschlagen. Bitte später erneut versuchen.';
	@override String get momentsDeleteFailed => 'Löschen fehlgeschlagen. Bitte später erneut versuchen.';
	@override String get momentsReportSubmitted => 'Meldung gesendet';
	@override String get momentsReportFailed => 'Meldung fehlgeschlagen. Bitte später erneut versuchen.';
	@override String get momentReportReasonSpam => 'Spam oder Werbung';
	@override String get momentReportReasonHarassment => 'Belästigung';
	@override String get momentReportReasonPorn => 'Pornografie';
	@override String get momentReportReasonFraud => 'Betrug';
	@override String get momentReportReasonInfringement => 'Urheberrechtsverletzung';
	@override String get momentReportReasonOther => 'Sonstiges';
	@override String get momentReportReasonPrompt => 'Grund auswählen';
	@override String get momentsLoadMoreComments => 'Weitere Kommentare laden';
	@override String get momentsUploadFailed => 'Medien-Upload fehlgeschlagen. Bitte später erneut versuchen.';
	@override String get saveFailed => 'Speichern fehlgeschlagen';
	@override String get confirm => 'Bestätigen';
	@override String get success => 'Erfolg';
	@override String get personalDisplay => 'Persönliche Anzeige';
	@override String get personalSignature => 'Persönliche Signatur';
	@override String get personalBackground => 'Persönlicher Hintergrund';
	@override String get expression => 'Emoji';
	@override String get extendedInfo => 'Erweiterte Informationen';
	@override String get profession => 'Beruf';
	@override String get shareFailed => 'Teilen fehlgeschlagen';
	@override String exportSuccessThenCopiedToClipboard({required Object param}) => 'Profil im ${param}-Format exportiert und in die Zwischenablage kopiert';
	@override String get setRegion => 'Region festlegen';
	@override String get deleteOperationAbnormal => 'Löschvorgang anomal, bitte versuchen Sie es erneut';
	@override String get revoking => 'Wird widerrufen...';
	@override String get editing => 'Wird bearbeitet...';
	@override String get messageIdCannotBeEmpty => 'Nachrichten-ID ist leer, Vorgang kann nicht durchgeführt werden';
	@override String get startRevokeMessageFlow => 'Widerruf-Nachrichtenablauf starten';
	@override String get revokeMessageTracking => 'Widerruf-Nachrichtenverfolgung';
	@override String get useNewActionMechanism => 'Neuen Action-Mechanismus verwenden';
	@override String get revokeMessageSendResult => 'Widerruf-Nachrichtensendergebnis';
	@override String get revokeRequestSendComplete => 'Widerruf-Anfrage gesendet';
	@override String get revokeFailed => 'Widerruf fehlgeschlagen';
	@override String get revokeMessageException => 'Widerruf-Nachrichtenausnahme';
	@override String get revokeOperationAbnormal => 'Widerrufsvorgang anomal';
	@override String get startEditMessageFlow => 'Bearbeitungs-Nachrichtenablauf starten';
	@override String get editMessageTracking => 'Bearbeitungs-Nachrichtenverfolgung';
	@override String get newContent => 'Neuer Inhalt';
	@override String get editMessageSendResult => 'Bearbeitungs-Nachrichtensendergebnis';
	@override String get editRequestSendComplete => 'Bearbeitungsanfrage gesendet';
	@override String get editFailed => 'Bearbeitung fehlgeschlagen';
	@override String get editMessageException => 'Bearbeitungs-Nachrichtenausnahme';
	@override String get editOperationAbnormal => 'Bearbeitungsvorgang anomal';
	@override String get error => 'Fehler';
	@override String get cannotOpenWebpage => 'Webseite kann nicht geöffnet werden';
	@override String get selectImageFailedWithError => 'Bildauswahl fehlgeschlagen';
	@override String get reactionAdded => 'Reaktion hinzugefügt';
	@override String get reactionCancelled => 'Reaktion abgebrochen';
	@override String get retryFailedPleaseCheckNetwork => 'Wiederholung fehlgeschlagen, bitte Netzwerkverbindung überprüfen';
	@override String get retryAbnormal => 'Wiederholungsanomalie';
	@override String get deleteFailedPleaseTryAgain => 'Löschen fehlgeschlagen, bitte erneut versuchen';
	@override String get deleteFailedPleaseCheckNetwork => 'Löschen fehlgeschlagen, bitte Netzwerkverbindung überprüfen';
	@override String get seconds => 'Sekunden';
	@override String get settingFailedPleaseTryAgain => 'Einstellung fehlgeschlagen, bitte erneut versuchen';
	@override String partialDeleteSuccess({required Object success, required Object fail}) => 'Teilweises Löschen erfolgreich: ${success} erfolgreich, ${fail} fehlgeschlagen';
	@override String get recordingCancelled => 'Aufnahme abgebrochen';
	@override String get pullOfflineMessagesFailed => 'Abruf von Offline-Nachrichten fehlgeschlagen';
	@override String get pullOfflineMessagesAbnormal => 'Abruf von Offline-Nachrichten fehlgeschlagen';
	@override String get logoutRequestFailedPleaseCheckNetwork => 'Abmeldeanforderung fehlgeschlagen, bitte Netzwerkverbindung überprüfen';
	@override String get permissionOnlySupportAndroidAndIos => 'Berechtigung unterstützt nur Android und iOS';
	@override String get retryingSend => 'Wiederholung wird gesendet...';
	@override String get quickReplyOk => 'Okay';
	@override String get quickReplyOkThanks => 'OK, danke';
	@override String get noDetailedInfo => 'Dieser Benutzer hat keine persönliche Signatur und keine detaillierten Informationen festgelegt';
	@override String get noNewRegisteredUsers => 'Derzeit keine neuen registrierten Benutzer Bitte kommen Sie später zurück';
	@override String get newRegisteredUsersTip => 'Kürzlich registrierte Benutzer werden hier angezeigt, Sie können sie als Freunde hinzufügen';
	@override String get notificationFriendRequest => 'Freundschaftsanfrage';
	@override String notificationFriendRequestBody({required Object requesterName}) => '${requesterName} möchte Sie als Freund hinzufügen';
	@override String get notificationGroupInvite => 'Gruppeneinladung';
	@override String notificationGroupInviteBody({required Object inviterName, required Object groupName}) => '${inviterName} lädt Sie in die Gruppe ${groupName} ein';
	@override String get youRevokedMessage => 'Sie haben eine Nachricht widerrufen';
	@override String get otherRevokedMessage => 'Der Gesprächspartner hat eine Nachricht widerrufen';
	@override String get networkFailureTryAgain => 'Netzwerkfehler, bitte versuchen Sie es erneut!';
	@override String get networkNotAvailable => 'Netzwerk derzeit nicht verfügbar.';
	@override String get pleaseCheckNetworkConnection => 'Bitte überprüfen Sie Ihre Netzwerkverbindung.';
	@override String lastSeenMinutesAgo({required num n}) => _root.common.timeMinutesAgo(n: n);
	@override String lastSeenHoursAgo({required num n}) => _root.common.timeHoursAgo(n: n);
	@override String lastSeenDaysAgo({required num n}) => _root.common.timeDaysAgo(n: n);
	@override String get fontSettings => _root.common.fontSizeSetting;
	@override String get noFavoritesYet => 'Noch keine Favoriten. Sammeln Sie einige interessante Nachrichten!';
	@override String get fontPreviewText => 'Dies ist der Fließtext. Sie können hier sehen, wie verschiedene Schriftgrößen aussehen.';
	@override String get smaller => 'Kleiner';
	@override String currentFontScale({required Object param1, required Object param2}) => 'Aktuell: ${param1} ${param2}%';
	@override String groupAnnouncementExpiry({required Object time}) => 'Gültig bis: ${time}';
	@override String get groupAlbumCreateFailed => 'Erstellen fehlgeschlagen. Bitte später erneut versuchen.';
	@override String get groupAlbumDeleteTitle => 'Gruppenalbum löschen';
	@override String groupAlbumDeleteConfirm({required Object name}) => 'Album „${name}" wirklich löschen?';
	@override String get groupAlbumDeleted => 'Album gelöscht';
	@override String get groupAlbumDeleteFailed => 'Löschen fehlgeschlagen. Bitte später erneut versuchen.';
	@override String get groupAlbumRenameFailed => 'Umbenennen fehlgeschlagen. Bitte später erneut versuchen.';
	@override String get groupAlbumUploadTooltip => 'Bild hochladen';
	@override String get groupAlbumDeleteTooltip => 'Album löschen';
	@override String get groupAlbumNoAlbum => 'Keine Gruppenalben';
	@override String get groupAlbumPhotoReadFailed => 'Bild konnte nicht gelesen werden. Bitte erneut versuchen.';
	@override String get groupAlbumPhotoUploaded => 'Bild hochgeladen';
	@override String get groupAlbumPhotoUploadFailed => 'Bild-Upload fehlgeschlagen. Bitte später erneut versuchen.';
	@override String get groupAlbumCreateTooltip => 'Album erstellen';
	@override String get groupAlbumPhotoBatchDeleteTitle => 'Bilder löschen';
	@override String groupAlbumPhotoBatchDeleteConfirm({required Object count}) => '${count} ausgewählte Bilder wirklich löschen?';
	@override String get groupAlbumPhotoDeleteFailed => 'Löschen fehlgeschlagen. Bitte später erneut versuchen.';
	@override String groupAlbumPhotoDeletedAll({required Object count}) => '${count} Bilder gelöscht';
	@override String groupAlbumPhotoDeletedPartial({required Object success, required Object fail}) => '${success} gelöscht, ${fail} fehlgeschlagen';
	@override String get groupAlbumPhotoDeleteTitle => 'Bild löschen';
	@override String get groupAlbumPhotoDeleteConfirm => 'Dieses Bild wirklich löschen?';
	@override String get groupAlbumPhotoDeleted => 'Bild gelöscht';
	@override String get groupAlbumPhotoBatchDeleteTooltip => 'Löschen';
	@override String get groupAlbumPhotoExitSelection => 'Auswahl verlassen';
	@override String get groupAlbumPhotoOpenFailed => 'Bildlink kann nicht geöffnet werden';
	@override String get groupAlbumPhotoNotFound => 'Bild existiert nicht oder wurde gelöscht';
	@override String get groupAlbumPhotoOpenExternal => 'In der App öffnen';
	@override String get groupAlbumPhotoCoverUpdated => 'Als Album-Cover festgelegt';
	@override String get groupAlbumPhotoCoverFailed => 'Cover konnte nicht festgelegt werden. Bitte später erneut versuchen.';
	@override String get groupAlbumPhotoNext => 'Weiter';
	@override String get groupAlbumPhotoResolution => 'Auflösung';
	@override String get groupAlbumPhotoUploader => 'Hochgeladen von';
	@override String get sectionDisplay => 'Anzeige';
	@override String get sectionTheme => 'Design';
	@override String get selectLanguage => 'Sprache wählen';
	@override String get completionSuggestions => 'Tipps:';
	@override String get sectionGeneral => 'Allgemein';
	@override String get sectionPrivacySecurity => 'Datenschutz & Sicherheit';
	@override String get sectionHelpAbout => 'Hilfe & Info';
	@override String get msgOnlyVisibleToParties => 'Nachricht nur für Absender und Empfänger lesbar';
	@override String get msgNotEncrypted => 'Nachricht unverschlüsselt';
	@override String unreadCount({required Object count}) => '${count} ungelesen';
	@override String durationMinutes({required Object count}) => '${count} Min.';
	@override String durationSeconds({required Object count}) => '${count} Sek.';
	@override String get rechargeAmountError => 'Betrag zwischen 0.01 und 10000 Yuan eingeben';
	@override String get rechargeSuccess => 'Aufgeladen';
	@override String get rechargeConfirm => 'Aufladen bestätigen';
	@override String get transactionHistory2 => 'Umsätze';
	@override String get noTransactionHistory => 'Keine Umsätze';
	@override String get transactionTypeIncome => 'Aufladung';
	@override String get transactionTypeExpense => 'Ausgabe';
	@override String get sectionLoginCredentials => 'Zugangsdaten';
	@override String get channelInvitations => 'Kanal-Einladungen';
	@override String get acceptInvitationFailed => 'Annehmen fehlgeschlagen';
	@override String get rejectInvitationFailed => 'Ablehnen fehlgeschlagen';
	@override String get invitationAccepted => 'Einladung angenommen';
	@override String get invitationRejected => 'Einladung abgelehnt';
	@override String get invitationStatusPending => 'Ausstehend';
	@override String get invitationStatusAccepted => 'Angenommen';
	@override String get invitationStatusRejected => 'Abgelehnt';
	@override String get invitationStatusExpired => 'Abgelaufen';
	@override String get invitationStatusCancelled => 'Abgesagt';
	@override String get invitationStatusUnknown => 'Unbekannt';
	@override String get noReceivedInvitations => 'Keine erhaltenen Einladungen';
	@override String get noSentInvitations => 'Keine gesendeten Einladungen';
	@override String get processingDots => 'Wird verarbeitet...';
	@override String get purchaseFailed => 'Kauf fehlgeschlagen. Bitte später erneut versuchen.';
	@override String get purchaseSuccess => 'Gekauft';
	@override String get insufficientBalanceTitle => 'Guthaben unzureichend';
	@override String insufficientBalanceContent({required Object currency, required Object balance, required Object price}) => 'Aktuelles Guthaben: ${currency} ${balance}, benötigt: ${currency} ${price}. Bitte zuerst aufladen.';
	@override String get goRecharge => 'Aufladen';
	@override String get noOrders => 'Keine Bestellungen';
	@override String get orderDetailLoadFailed => 'Bestelldetails konnten nicht geladen werden';
	@override String orderNoLabel({required Object no}) => 'Bestellnr.: ${no}';
	@override String get orderStatusCancelled => 'Abgesagt';
	@override String get orderStatusUnknown => 'Unbekannt';
	@override String get fileOpenFailed => 'Datei kann nicht geöffnet werden';
	@override String get e2eeLocalBackup => 'Lokales Backup';
	@override String get e2eeLocalBackupDesc => 'Verschlüsseltes Backup lokal oder in der Cloud speichern';
	@override String get e2eeDeleteKey => 'Schlüssel löschen';
	@override String get e2eeDeleteKeyDesc => 'Lokalen Schlüssel löschen (nicht wiederherstellbar)';
	@override String get e2eeCurrentKeyInfo => 'Aktueller Schlüssel';
	@override String get e2eeE2EEEnabled => 'E2EE aktiv';
	@override String get e2eeNoKeyDetected => 'Kein E2EE-Schlüssel gefunden';
	@override String get e2eeNoKeyDesc => 'Bitte Schlüsselpaar erstellen oder aus Backup wiederherstellen';
	@override String get e2eeAboutTitle => 'Über E2EE';
	@override String get e2eeInfoPoint1 => '• Nachrichten werden vor dem Senden verschlüsselt, Server sehen keinen Inhalt';
	@override String get e2eeInfoPoint2 => '• Nach Gerätewechsel oder Schlüssellöschung sind alte Nachrichten evtl. nicht entschlüsselbar';
	@override String get e2eeInfoPoint3 => '• Schlüssel regelmäßig sichern, um Datenverlust zu vermeiden';
	@override String get e2eeExportBackup => 'Backup exportieren';
	@override String get e2eeExportBackupDesc => 'Verschlüsseltes Backup erstellen';
	@override String get e2eeImportBackup => 'Backup importieren';
	@override String get e2eeImportBackupDesc => 'Schlüssel aus Backup wiederherstellen';
	@override String get e2eeGenerateKeyConfirm => 'Neues E2EE-Schlüsselpaar erstellen?';
	@override String get e2eeWarnOldMessagesLost => '• Alte Nachrichten nicht mehr entschlüsselbar';
	@override String get e2eeWarnNeedNewBackup => '• Neues Backup erforderlich';
	@override String get e2eeConfirmGenerate => 'Erstellen';
	@override String get aiPlaintextConfirmTitle => 'Klartext-Chat mit KI-Assistent';
	@override String get aiPlaintextConfirmBody => 'Nachrichten und Anhänge in diesem Chat sind NICHT Ende-zu-Ende-verschlüsselt; der Server kann sie lesen.';
	@override String get aiPlaintextConfirmNote => 'Dieses Gerät merkt sich die Bestätigung und fragt erneut, wenn sich Identität oder Schlüssel des Gegenübers ändern.';
	@override String get aiPlaintextConfirmOk => 'Verstanden, senden';
	@override String get aiPlaintextConfirmCancel => 'Abbrechen';
	@override String get e2eeDeleteKeyConfirm => 'Aktuellen Schlüssel wirklich löschen?';
	@override String get e2eeWarnCannotRestore => '• Nach Löschen nicht wiederherstellbar';
	@override String get e2eeWarnAllMsgsLost => '• Alle E2EE-Nachrichten nicht mehr entschlüsselbar';
	@override String get e2eeConfirmDelete => 'Löschen';
	@override String get e2eeKeyGeneratedSuccess => 'Schlüssel erstellt';
	@override String e2eeDeviceIdInfo({required Object id}) => 'Geräte-ID: ${id}';
	@override String e2eeKeyIdInfo({required Object id}) => 'Schlüssel-ID: ${id}';
	@override String e2eeCreatedAtInfo({required Object time}) => 'Erstellt am: ${time}';
	@override String get e2eeImportantNote => 'Wichtiger Hinweis';
	@override String get e2eeWarnOldMayNotDecrypt => '• Alte Nachrichten evtl. nicht entschlüsselbar';
	@override String get e2eeSuggestBackupNow => '• Backup jetzt empfohlen';
	@override String get e2eeGoBackup => 'Zum Backup';
	@override String get e2eeKeyGenerateFailed => 'Schlüsselerstellung fehlgeschlagen. Bitte erneut versuchen.';
	@override String get e2eeKeyDeleted => 'Schlüssel gelöscht';
	@override String get e2eeDeleteFailed => 'Löschen fehlgeschlagen. Bitte erneut versuchen.';
	@override String get webFeatureNotification => 'Desktop-Benachrichtigungen';
	@override String get webFeatureNotificationDesc => 'Neue Nachrichten auch bei inaktiver App';
	@override String get webQRConfirmOnPhone => 'Bitte am Handy bestätigen';
	@override String get webQRLoginFailed => 'Anmeldung fehlgeschlagen';
	@override String get webQRLoginSuccess => 'Angemeldet';
	@override String webQRExpiresIn({required Object seconds}) => 'Läuft in ${seconds} Sek. ab';
	@override String get webQRStatusFailed => 'Anmeldung fehlgeschlagen. Bitte erneut versuchen.';
	@override String get webQRStatusSuccess => 'Weiterleitung...';
	@override String get webLoginEmptyError => 'Konto und Passwort eingeben';
	@override String get webQRGenerateFailed => 'QR-Code konnte nicht erstellt werden';
	@override String get webQRTokenInvalid => 'Anmelde-Token ungültig';
	@override String get e2eeErrNoRecipientKey => 'Geräteschlüssel des Empfängers nicht verfügbar, Nachricht nicht gesendet';
	@override String get e2eeDecryptFailed => 'Nachricht kann nicht entschlüsselt werden';
	@override String get e2eeDecryptFailedReasons => 'Nachricht nicht entschlüsselbar. Mögliche Ursachen:';
	@override String get e2eeDecryptReasonOtherDevice => '• Anmeldung auf anderem Gerät';
	@override String get e2eeDecryptReasonKeyExpired => '• Geräteschlüssel abgelaufen';
	@override String get e2eeDecryptReasonDataCorrupt => '• App-Daten beschädigt';
	@override String get e2eeDecryptChooseSolution => 'Lösung wählen:';
	@override String get e2eeDecryptRecreateHint => 'Hinweis: Nach der Neuerstellung muss die Gegenseite Ihren neuen Schlüssel abrufen; während der Änderung noch nicht zugestellte verschlüsselte Nachrichten werden möglicherweise nicht automatisch erneut gesendet. Der Nachrichtenverlauf ist nicht betroffen.';
	@override String get e2eePeerKeyChanged => 'Die Sicherheitsnummer dieses Kontakts hat sich geändert (möglicherweise wurde die App neu installiert oder das Gerät gewechselt). Wenn dir Sicherheit wichtig ist, überprüfe die Identität über einen anderen Kanal.';
	@override String get e2eeDecryptActionRecreateKey => 'Schlüssel neu erstellen (empfohlen)';
	@override String get e2eeDecryptActionRelogin => 'Neu anmelden';
	@override String get e2eeDecryptActionRemindLater => 'Später erinnern';
	@override String get e2eeBackupExportTitle => 'E2EE-Backup exportieren';
	@override String get e2eeBackupPwdCantRecover => '• Backup-Passwort nicht wiederherstellbar, gut aufbewahren!';
	@override String get e2eeBackupStoreMultipleNote => '• Backup an mehreren Orten speichern (E-Mail, Cloud, USB-Stick)';
	@override String get e2eeBackupPwdLabel => 'Backup-Passwort *';
	@override String get e2eeBackupPwdHint => 'Min. 12 Zeichen, Groß-/Kleinschreibung, Zahlen, Sonderzeichen';
	@override String get e2eeBackupConfirmPwdLabel => 'Passwort bestätigen *';
	@override String get e2eeBackupConfirmPwdHint => 'Passwort wiederholen';
	@override String get e2eeBackupNoteLabel => 'Notiz (optional)';
	@override String get e2eeBackupNoteHint => 'z. B. Hauptgerät-Backup - Jan 2026';
	@override String get e2eeBackupPwdStrengthLabel => 'Passwortstärke';
	@override String get e2eeBackupPwdWeak => 'Schwach';
	@override String get e2eeBackupPwdMedium => 'Mittel';
	@override String get e2eeBackupPwdStrong => 'Stark';
	@override String get e2eeBackupPwdVeryStrong => 'Sehr stark';
	@override String get e2eeBackupGenerateBtn => 'Backup erstellen';
	@override String get e2eeBackupFileGenerated => 'Backup erstellt!';
	@override String get e2eeBackupShareBtn => 'Per E-Mail/Cloud teilen';
	@override String get e2eeBackupShareContent => 'Mein Imboy E2EE-Schlüssel-Backup. Sicher aufbewahren, nicht weitergeben.';
	@override String get e2eeBackupErrPwdMismatch => 'Passwörter stimmen nicht überein';
	@override String get e2eeBackupErrNoKeyData => 'Schlüsseldaten nicht verfügbar';
	@override String get e2eeBackupErrExportFailed => 'Export fehlgeschlagen. Bitte erneut versuchen.';
	@override String get e2eeBackupErrShareFailed => 'Teilen fehlgeschlagen. Bitte erneut versuchen.';
	@override String get e2eeBackupExportSuccessTitle => 'Backup exportiert';
	@override String get e2eeBackupExportSuccessBody => 'E2EE-Backup wurde erstellt.';
	@override String get e2eeBackupImportantNoteColon => 'Wichtig:';
	@override String get e2eeBackupKeepSafe => '• Backup und Passwort sicher aufbewahren';
	@override String get e2eeBackupStoreMultipleLoc => '• An mehreren Orten speichern';
	@override String get e2eeBackupPwdCantRecoverNote => '• Passwort nicht wiederherstellbar';
	@override String get e2eeBackupImportTitle => 'E2EE-Backup importieren';
	@override String get e2eeBackupImportGuide => 'Hinweise';
	@override String get e2eeBackupImportReplaceKey => '• Aktueller Schlüssel wird beim Import ersetzt';
	@override String get e2eeBackupImportTrustedSource => '• Nur Backups aus vertrauenswürdiger Quelle';
	@override String get e2eeBackupSelectFile => 'Backup-Datei wählen';
	@override String get e2eeBackupSelectFileHint => 'Tippen, um Backup zu wählen (.enc)';
	@override String get e2eeBackupInfoTitle => 'Backup-Info';
	@override String get e2eeBackupVersionLabel => 'Version';
	@override String get e2eeBackupAlgorithmLabel => 'Algorithmus';
	@override String get e2eeBackupFileSizeLabel => 'Dateigröße';
	@override String e2eeBackupFileBytes({required Object bytes}) => '${bytes} Bytes';
	@override String e2eeBackupGeneratedFile({required Object name}) => 'Datei: ${name}';
	@override String get e2eeBackupFileValid => '✓ Format gültig';
	@override String get e2eeBackupImportPwdHint => 'Backup-Passwort eingeben';
	@override String get e2eeBackupImportBtn => 'Schlüssel importieren';
	@override String get e2eeBackupErrSelectFile => 'Dateiauswahl fehlgeschlagen. Bitte erneut versuchen.';
	@override String get e2eeBackupErrValidateFailed => 'Validierung fehlgeschlagen. Format prüfen.';
	@override String get e2eeBackupErrImportFailed => 'Import fehlgeschlagen. Passwort prüfen.';
	@override String get e2eeBackupImportSuccessTitle => 'Importiert';
	@override String get e2eeBackupImportSuccessBody => 'E2EE-Schlüssel wiederhergestellt!';
	@override String get e2eeBackupImportSuccessNote => 'Hinweis: Nur Gruppensitzungen, die in dieser Sicherung enthalten und erfolgreich gespeichert wurden, können den zugehörigen Verlauf entschlüsseln. Einzelchats sind nicht wiederherstellbar, da 1:1-Schlüssel nicht geräteübergreifend gesichert werden.';
	@override String get e2eeBackupHistoryGrantTitle => 'Historische Gruppenschlüssel wiederherstellen';
	@override String e2eeBackupHistoryGrantBody({required Object count}) => 'Dies autorisiert dieses Gerät separat, ${count} Gruppenschlüssel wiederherzustellen und Verlauf nur innerhalb der jeweiligen Mitgliedschaftsgeneration und Nachrichtensequenz zu entschlüsseln. Identitätsschlüssel wurden bereits wiederhergestellt; Abbrechen überspringt diese Gruppenschlüssel.';
	@override String e2eeBackupHistoryRestoreResult({required Object restored, required Object omitted}) => 'Historische Gruppenschlüssel: ${restored} autorisiert und wiederhergestellt, ${omitted} ausgelassen';
	@override String get e2eeBackupErrAccountMismatch => 'Dieses Backup gehört zu einem anderen Konto; Wiederherstellung abgelehnt';
	@override String get e2eeBackupErrStaleBackup => 'Dieses Backup ist älter als die zuletzt erfolgreiche Wiederherstellung auf diesem Gerät (möglicher Replay); abgelehnt';
	@override String get e2eeBackupRestorePartialTitle => 'Teilweise abgeschlossen';
	@override String e2eeBackupRestorePartialBody({required Object written, required Object total}) => 'E2EE-Schlüssel wiederhergestellt; das Schreiben der Gruppenschlüssel wurde unterbrochen (${written}/${total} Einträge). Dieselbe Backup-Datei erneut importieren, um fortzufahren — wiederholtes Schreiben ist sicher';
	@override String get e2eeBackupSafetyNumberChangedNote => 'Der Identitätsschlüssel dieses Geräts hat sich geändert, daher ändern sich die Sicherheitsnummern mit deinen Kontakten. Bitte erneut verifizieren';
	@override String get e2eeBackupCreatedAtRow => 'Erstellt am';
	@override String get e2eeBackupCloudUploadBtn => 'In die Cloud sichern';
	@override String e2eeBackupCloudUploadSuccess({required Object version}) => 'In der Cloud gesichert (Version ${version})';
	@override String get e2eeBackupErrCloudUploadFailed => 'Cloud-Backup fehlgeschlagen, bitte erneut versuchen';
	@override String get e2eeBackupCloudRestoreTitle => 'Aus Cloud-Backup wiederherstellen';
	@override String e2eeBackupCloudRestoreHint({required Object version}) => 'Cloud-Backup erkannt (Version ${version})';
	@override String get e2eeBackupCloudRestoreBtn => 'Aus der Cloud wiederherstellen';
	@override String get e2eeBackupCloudRestoreConfirmNote => 'Die Wiederherstellung überschreibt die aktuellen E2EE-Schlüssel auf diesem Gerät';
	@override String get e2eeBackupCloudPwdHint => 'Backup-Passphrase eingeben';
	@override String get e2eeBackupErrNoCloudBackup => 'Kein Cloud-Backup vorhanden';
	@override String get e2eeBackupErrCloudPwd => 'Falsche Passphrase oder beschädigtes Backup';
	@override String get e2eeBackupErrCloudRestoreFailed => 'Cloud-Wiederherstellung fehlgeschlagen, bitte erneut versuchen';
	@override String get e2eeBackupUrlImportTitle => 'Oder über einen Link importieren';
	@override String get e2eeBackupUrlImportHint => 'Fügen Sie die URL der Backupdatei ein (nur HTTPS); sie wird automatisch heruntergeladen und verifiziert';
	@override String get e2eeBackupUrlFieldLabel => 'URL der Backupdatei';
	@override String get e2eeBackupUrlFieldHint => 'https://...';
	@override String get e2eeBackupUrlImportBtn => 'Herunterladen und verifizieren';
	@override String get e2eeBackupUrlDownloading => 'Wird heruntergeladen…';
	@override String get e2eeBackupErrUrlInvalid => 'Ungültige URL, nur HTTPS';
	@override String get e2eeBackupErrUrlDownload => 'Download fehlgeschlagen, bitte URL und Netzwerk prüfen';
	@override String get e2eeBackupErrUrlTimeout => 'Download-Zeitüberschreitung, bitte erneut versuchen';
	@override String get e2eeBackupErrUrlTls => 'Sichere Verbindung fehlgeschlagen, Serverzertifikat konnte nicht verifiziert werden';
	@override String get e2eeBackupErrUrlHttp => 'Server hat einen Fehler zurückgegeben';
	@override String get e2eeBackupErrUrlEmpty => 'Server hat leeren Inhalt zurückgegeben';
	@override String get e2eeBackupErrUrlTooLarge => 'Datei zu groß (10MB-Limit überschritten)';
	@override String get passwordEncryptFailed => 'Passwort-Verschlüsselung fehlgeschlagen';
	@override String get initConfigTimeout => 'Zeitüberschreitung: Netzwerk oder Server prüfen';
	@override String initConfigNetworkError({required Object code}) => 'Netzwerk- oder Serverfehler (HTTP ${code})';
	@override String get initConfigProtocolError => 'Server-Protokoll fehlerhaft';
	@override String get initConfigFetchFailed => 'Konfiguration konnte nicht geladen werden. Netzwerk prüfen.';
	@override String get saveFailedRetry => 'Speichern fehlgeschlagen. Bitte erneut versuchen.';
	@override String get downloadFileNotFound => 'Download-Datei nicht vorhanden. Bitte erneut versuchen.';
	@override String downloadHashRetrying({required Object retry, required Object max}) => 'Prüfung fehlgeschlagen, erneut laden (${retry}/${max})';
	@override String get downloadHashFailed => 'Mehrfachprüfung fehlgeschlagen. Netzwerk prüfen.';
	@override String get buttonBackHome => 'Zum Start';
	@override String get featureNotEnabled => 'Funktion nicht verfügbar';
	@override String featureDisabledName({required Object name}) => '${name}-Funktion nicht verfügbar';
	@override String get imageLoadFailed => 'Laden fehlgeschlagen';
	@override String loadFailedWithError({required Object error}) => 'Laden fehlgeschlagen: ${error}';
	@override String get webAudioNotSupported => 'Sprachnachrichten im Web nicht unterstützt';
	@override String e2eeKeyRecreationFailed({required Object error}) => 'Fehler: ${error}';
	@override String get redPacket => 'Geschenk';
	@override String get transfer => 'Überweisung';
	@override String get withdraw => 'Auszahlung';
	@override String get redPacketSend => 'Geschenk senden';
	@override String get redPacketDetail => 'Geschenk-Details';
	@override String get transferSend => 'Überweisung starten';
	@override String get greetingDefault => 'Frohes neues Jahr';
	@override String transferAmountYuan({required Object amount}) => 'Überwiesen: ${amount} Yuan';
	@override String get insufficientBalance => 'Guthaben unzureichend';
	@override String get withdrawSuccess => 'Auszahlung erfolgreich';
	@override String get withdrawConfirm => 'Auszahlung bestätigen';
	@override String get withdrawFeeNotice => 'Gebühren und Gutschriftsdauer richten sich nach der tatsächlichen Abrechnung';
	@override String get withdrawAmountError => 'Mindestens 0.01 Yuan eingeben';
	@override String get withdrawAccountEmpty => 'Auszahlungskonto eingeben';
	@override String get withdrawMethod => 'Auszahlungsmethode';
	@override String get withdrawAmountLabel => 'Auszahlungsbetrag';
	@override String get withdrawAlipay => 'Alipay';
	@override String get withdrawWechat => 'WeChat';
	@override String walletBalanceLabel({required Object balance}) => 'Guthaben ￥${balance}';
	@override String get withdrawAccountHintAlipay => 'Auszahlungskonto (E-Mail oder Telefonnummer)';
	@override String get withdrawAccountHintWechat => 'Auszahlungskonto (WeChat-ID)';
	@override String get withdrawAlipayFormatError => 'Bitte eine gültige Alipay-E-Mail-Adresse oder Telefonnummer eingeben';
	@override String get withdrawWechatFormatError => 'Bitte eine gültige WeChat-ID eingeben (6-20 Zeichen, beginnend mit einem Buchstaben)';
	@override String withdrawConfirmAmount({required Object amount}) => 'Auszahlungsbetrag: ￥${amount}';
	@override String withdrawConfirmMethod({required Object method}) => 'Auszahlungsmethode: ${method}';
	@override String withdrawConfirmAccount({required Object account}) => 'Auszahlungskonto: ${account}';
	@override String get showPassword => 'Passwort anzeigen';
	@override String get hidePassword => 'Passwort ausblenden';
	@override String get turnOnFlashlight => 'Taschenlampe einschalten';
	@override String get turnOffFlashlight => 'Taschenlampe ausschalten';
	@override String get pauseScan => 'Scan pausieren';
	@override String get resumeScan => 'Scan fortsetzen';
	@override String get enterFullscreen => 'Vollbild aktivieren';
	@override String get exitFullscreen => 'Vollbild beenden';
	@override String get developer => 'Entwickler';
	@override String get fontSizeOptionSmall => 'Klein';
	@override String get fontSizeOptionNormal => 'Standard';
	@override String get fontSizeOptionMedium => 'Mittel';
	@override String get fontSizeOptionLarge => 'Groß';
	@override String get fontSizeOptionExtraLarge => 'Sehr groß';
	@override String get fontSizeOptionHuge => 'Riesig';
	@override String get searchFailedRetry => 'Suche fehlgeschlagen, bitte erneut versuchen';
	@override String get searchDisabledTitle => 'Nachrichtensuche nicht verfügbar';
	@override String get searchDisabledByEncryption => 'Ende-zu-Ende-Verschlüsselung ist aktiv; der Server kann die Nachrichten nicht lesen, daher gibt es keine Volltextsuche';
	@override String get collectedVideoFormatIncorrectCannotFindVideoUri => 'Videoformat nicht unterstützt, Video-URI nicht auffindbar';
	@override String get justNow => 'Gerade eben';
	@override String get minutesAgo => 'Min.';
	@override String get hoursAgo => 'Std.';
	@override String get me => 'Ich';
	@override String get minimize => 'Minimieren';
	@override String get collapse => 'Einklappen';
	@override String get expandFull => 'Ausklappen';
	@override String get noHistory => 'Kein Verlauf';
	@override String get noNewRegisteredUsersTitle => 'Keine neuen registrierten Nutzer';
	@override String get answer => 'Annehmen';
	@override String get declineCall => 'Ablehnen';
	@override String get switchCamera => 'Kamera wechseln';
	@override String get reconnecting => 'Schlechte Verbindung, wird neu verbunden…';
	@override String get amountMustPositive => 'Betrag muss größer als 0 sein';
	@override String get enterAmount => 'Bitte Betrag eingeben';
	@override String f2fEnteringGroup({required Object count}) => '${count} Personen treten gleich dem Gruppenchat bei';
	@override String get f2fSecretCode => 'Geheimcode';
	@override String uploadPartialFailed({required Object count}) => '${count} Uploads fehlgeschlagen';
	@override String get momentsHasFailedUploads => 'Einige Medien wurden nicht hochgeladen. Bitte erneut versuchen oder entfernen und dann veröffentlichen';
	@override String get payReceiveSuccess => 'Zahlung empfangen!';
	@override String get purchaseConfirming => 'Zahlung wird bestätigt. Bitte später den Bestellstatus prüfen';
	@override String get timeNowShort => 'jetzt';
	@override String timeMinutesShort({required Object count}) => '${count} Min.';
	@override String timeHoursShort({required Object count}) => '${count} Std.';
	@override String timeDaysShort({required Object count}) => '${count} T';
	@override String get transferAccepted => 'Empfangen';
	@override String get transferAmountLabel => 'Überweisungsbetrag';
	@override String get transferConfirm => 'Überweisung bestätigen';
	@override String get transferDefaultRemark => 'Überweisung an Freund';
	@override String get transferMinAmountError => 'Mindestbetrag für Überweisungen: 0.01 Yuan';
	@override String get transferPending => 'Warten auf Bestätigung der Gegenseite';
	@override String get transferReceiving => 'Zahlung wird empfangen...';
	@override String get transferRefunded => 'Zurücküberwiesen';
	@override String get transferRemarkLabel => 'Überweisungsnotiz';
	@override String get transferTapToReceive => 'Zum Empfangen tippen';
	@override String get voiceSttConverting => 'Wird erkannt...';
	@override String get voiceSttNotConfigured => 'Sprache-zu-Text ist noch nicht konfiguriert';
	@override String get voiceSttPreviewTitle => 'Sprache-zu-Text-Vorschau';
	@override String get redPacketAmountTooSmall => 'Gesamtbetrag mindestens Anzahl × 0.01 Yuan';
	@override String get redPacketBrand => 'IMBoy-Geschenk';
	@override String get redPacketCount => 'Anzahl Geschenke';
	@override String get redPacketCountEmpty => 'Bitte Anzahl der Geschenke eingeben';
	@override String get redPacketCountMin => 'Anzahl muss mindestens 1 sein';
	@override String get redPacketCountUnit => 'Stk.';
	@override String get redPacketCurrentLucky => 'Aktuell: Zufallsbetrag';
	@override String get redPacketCurrentNormal => 'Aktuell: Festbetrag';
	@override String get redPacketDialogSubtitle => 'Viel Glück und großen Reichtum';
	@override String get redPacketDialogTitle => 'Ein Geschenk für Sie';
	@override String get redPacketFetchError => 'Fehler beim Laden der Geschenk-Details';
	@override String get redPacketFetchFailed => 'Geschenk-Details konnten nicht geladen werden';
	@override String get redPacketGreetingLabel => 'Nachricht / Glückwünsche';
	@override String get redPacketNotFound => 'Geschenk nicht gefunden oder bereits gelöscht';
	@override String redPacketReceiverLabel({required Object uid}) => 'Nutzer: ${uid}';
	@override String get redPacketSingleAmount => 'Einzelnbetrag';
	@override String get redPacketStuffLucky => 'Zufallsbeträge verteilen';
	@override String get redPacketStuffNormal => 'Festbetrag senden';
	@override String get redPacketSwitchToLucky => 'Zu Zufallsbetrag wechseln';
	@override String get redPacketSwitchToNormal => 'Zu Festbetrag wechseln';
	@override String get redPacketTotalAmount => 'Gesamtbetrag';
	@override String get redPacketView => 'Geschenk ansehen';
	@override String get e2eeErrPeerNotOnboarded => 'Die Gegenseite war noch auf keinem Gerät angemeldet, verschlüsseltes Senden derzeit nicht möglich. Bitte warten Sie, bis sich die Gegenseite angemeldet hat, und versuchen Sie es erneut';
	@override String get e2eeRecoveryKeyTitle => 'Wiederherstellungsschlüssel';
	@override String e2eeRecoveryKeyCopiedAutoClear({required Object seconds}) => 'Wiederherstellungsschlüssel kopiert. Die Zwischenablage wird in ${seconds} Sek. automatisch geleert. Bitte schnellstmöglich sichern';
	@override String get e2eeErrAttachmentSeal => 'Versiegeln der verschlüsselten Datei fehlgeschlagen, die Datei wurde nicht hochgeladen. Bitte später erneut versuchen';
	@override String get e2eeErrForwardPlaintextTarget => 'Der Ziel-Chat ist nicht Ende-zu-Ende-verschlüsselt; die verschlüsselte Datei kann nicht weitergeleitet werden';
	@override String get e2eeErrForwardUndecryptable => 'Die ursprüngliche verschlüsselte Datei kann auf diesem Gerät nicht entschlüsselt werden; Weiterleitung fehlgeschlagen';
	@override String get e2eeRetryFailedMessages => 'Nachrichten mit Entschlüsselungsfehler erneut versuchen';
	@override String e2eeRetryFailedDone({required Object count}) => '${count} Nachrichten mit Entschlüsselungsfehler erneut versucht';
	@override String get e2eeRetryFailedNone => 'Keine Nachrichten zum Wiederholen';
	@override String get e2eeModeStandard => 'Standardmodus';
	@override String get e2eeModeCompliance => 'Compliance-Verschlüsselung';
	@override String get e2eeModeStrict => 'Ende-zu-Ende-Verschlüsselung';
	@override String get e2eeRecoveryKeySaveNote => 'Bitte sichern Sie diesen Wiederherstellungsschlüssel sofort (Screenshot oder Passwort-Manager). Bei vergessener Passphrase ist er der einzige Schlüssel zum Entschlüsseln des Backups; geht er verloren, ist das Backup dauerhaft nicht wiederherstellbar.';
	@override String get e2eeUseRecoveryKey => 'Wiederherstellungsschlüssel erstellen (Ersatz-Zugang bei vergessener Passphrase)';
	@override String get complianceKeyChangedTitle => 'Compliance-Audit-Schlüssel hat sich geändert';
	@override String get complianceKeyChangedBody => 'Der vom Server bereitgestellte öffentliche Compliance-Schlüssel stimmt nicht mit dem lokal gepinnten Wert überein. Handelt es sich um eine beabsichtigte Schlüsselrotation durch den Administrator, tippen Sie auf „Rotation bestätigen“; andernfalls senden Sie keine weiteren verschlüsselten Nachrichten und kontaktieren Sie den Administrator zur Prüfung.';
	@override String get complianceKeyChangedActionConfirm => 'Rotation bestätigen';
	@override String get complianceKeyChangedActionKeep => 'Vorerst nicht bestätigen';
	@override String get initConfigDecryptFailed => 'Konfiguration konnte nicht entschlüsselt werden: Sicherheitsschlüssel von App und Server stimmen nicht überein. Bitte App aktualisieren oder Administrator kontaktieren';
	@override String get retry => 'Wiederholen';
	@override String get retrying => 'Wiederholung…';
}

// Path: complaint
class _Translations$complaint$de_DE extends Translations$complaint$zh_CN {
	_Translations$complaint$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get complaint => 'Beschwerde';
	@override String get e2eeConsentTitle => 'Verschlüsselte Beweise einreichen';
	@override String get e2eeConsentBody => 'Diese Nachricht ist Ende-zu-Ende-verschlüsselt; der Server kann ihren Inhalt nicht einsehen. Durch das Einreichen eines Auszugs wird der ausgewählte Klartext den Moderatoren zur Prüfung offengelegt. Stimmen Sie zu?';
	@override String get e2eeConsentSubmit => 'Zustimmen und einreichen';
	@override String get e2eeConsentDecline => 'Nur melden (ohne Inhalt)';
}

// Path: complaintReason
class _Translations$complaintReason$de_DE extends Translations$complaintReason$zh_CN {
	_Translations$complaintReason$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get spam => 'Spam';
	@override String get harassment => 'Belästigung';
	@override String get inappropriate => 'Unangemessener Inhalt';
	@override String get other => 'Sonstiges';
}

// Path: contact
class _Translations$contact$de_DE extends Translations$contact$zh_CN {
	_Translations$contact$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get blocked => 'Blockiert';
	@override String get applyChanges => 'Bitte starten Sie die App neu, um die Änderungen zu übernehmen';
	@override String get inputNewTag => 'Neuen Tag eingeben...';
	@override String get denylist => 'Sperrliste';
	@override String get denylistEmpty => 'Sperrliste ist leer';
	@override String get favoriteGroupTagsEtc => 'Favoriten, Namen, Gruppen, Tags usw.';
	@override String get newFriend => 'Neue Freunde';
	@override String get recommendToFriend => 'Freunden empfehlen';
	@override String get remark => 'Bemerkung';
	@override String get remarksTags => 'Bemerkungen und Tags';
	@override String get selectAGroup => 'Eine Gruppe auswählen';
	@override String get selectFriends => 'Freunde auswählen';
	@override String get tags => 'Tags';
	@override String get suggestedTags => 'Vorgeschlagene Tags';
	@override String get pleaseEnterRemark => 'Bitte Bemerkung eingeben';
	@override String get enterRemark => 'Bemerkung eingeben';
	@override String get pleaseEnterTags => 'Bitte Tags eingeben';
	@override String get momentsVisibilityFriends => 'Nur Freunde';
	@override String tagLengthExceeded({required Object param}) => 'Tag-Länge darf ${param} Zeichen nicht überschreiten';
	@override String maxTagsExceeded({required Object param}) => 'Maximal ${param} Tags erlaubt';
	@override String selectedTags({required Object param, required Object max}) => 'Ausgewählte Tags (${param}/${max})';
	@override String get friendRequestSent => 'Gesendet';
	@override String get channelMaxTagsCount => 'Max. 8 Tags';
	@override String get tagInputHint => 'Tag eingeben...';
}

// Path: discovery
class _Translations$discovery$de_DE extends Translations$discovery$zh_CN {
	_Translations$discovery$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get findNearbyPeople => 'Personen in der Nähe finden';
	@override String get moment => 'Momente';
	@override String get nearbyPeopleExplain => 'Benutzer in Ihrer Nähe können Ihr Profil sehen und Ihnen Nachrichten senden. Finden Sie neue Freunde oder beenden Sie das Teilen jederzeit.\nIhre Telefonnummer bleibt verborgen.';
	@override String get peopleNearby => 'Personen in der Nähe';
	@override String get scanResult => 'Scan-Ergebnis';
	@override String get myChannels => 'Meine Kanäle';
	@override String get otherUsersCanFindMe => 'Andere Benutzer können mich durch Suche finden';
	@override String get momentsDenyUidsLabel => 'Ausgeschlossen UIDs (kommagetrennt)';
	@override String get moments => 'Momente';
	@override String get momentsWriteComment => 'Kommentar schreiben...';
	@override String get momentsVisibility => 'Sichtbarkeit';
	@override String get momentsVisibilityPublic => 'Öffentlich';
	@override String get momentsVisibilityPartial => 'Teilweise';
	@override String get momentsVisibilityExclude => 'Ausnahmen';
	@override String get momentsDraftRestored => 'Letzter Entwurf wiederhergestellt';
	@override String get momentsFeedStale => 'Netzwerkfehler, zwischengespeicherte Inhalte werden angezeigt';
	@override String get momentActionLike => 'Gefällt mir';
	@override String get momentActionCancelLike => 'Gefällt mir nicht mehr';
	@override String get momentActionComment => 'Kommentieren';
	@override String get momentActionDelete => 'Löschen';
	@override String get momentActionReport => 'Melden';
	@override String get momentActionCancel => 'Abbrechen';
	@override String momentLikedBy({required Object names}) => '${names} gefällt das';
	@override String momentAndOthersLiked({required Object names, required Object count}) => '${names} und ${count} weiteren gefällt das';
	@override String momentLikesCountOnly({required Object count}) => '${count} Personen gefiel dies';
	@override String get momentContentPlaceholder => 'Woran denken Sie...';
	@override String get momentShowFull => 'Vollständig anzeigen';
	@override String get momentCollapse => 'Einklappen';
	@override String get momentsDraftKeepTitle => 'Entwurf behalten?';
	@override String get momentsDraftKeepMessage => 'Beim nächsten Mal weiterbearbeiten';
	@override String get momentsDraftDiscard => 'Verwerfen';
	@override String get momentsDraftKeep => 'Behalten';
	@override String get openChannel => 'Kanal öffnen';
	@override String get paidChannelLocked => 'Inhalt gesperrt (Kostenpflichtig)';
	@override String get webQRScanned => 'Gescannt';
	@override String get momentActionMore => 'Weitere Aktionen';
	@override String momentAtCount({required Object count}) => '${count} Personen';
	@override String momentAtReminded({required Object name}) => 'Benachrichtigt: ${name}';
	@override String momentAtRemindedMore({required Object name, required Object count}) => 'Benachrichtigt: ${name} und ${count} weitere';
	@override String get momentAtWho => 'Wen benachrichtigen?';
	@override String get momentLocation => 'Standort';
	@override String get momentLocationNone => 'Standort nicht anzeigen';
}

// Path: enterpriseApp
class _Translations$enterpriseApp$de_DE extends Translations$enterpriseApp$zh_CN {
	_Translations$enterpriseApp$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Unternehmens-App';
	@override String get badgeAppDelegated => 'Von App gesendet';
	@override String get badgeHumanDelegated => 'Mensch über App';
	@override String get originTitle => 'Nachrichtenherkunft';
	@override String get originSenderApplication => 'Von der Anwendung gesendet (Application)';
	@override String get originSenderHuman => 'Im Auftrag eines Menschen gesendet (Human sender)';
	@override String originApplicationId({required Object id}) => 'Quell-Anwendung ${id}';
	@override String get originHosted => 'Unternehmensgehostet (kein privater Chat)';
	@override String get originLabelSender => 'Absenderherkunft';
	@override String get originLabelEncryption => 'Verschlüsselung';
	@override String get originNonE2ee => 'Nicht Ende-zu-Ende verschlüsselt';
	@override String get originE2ee => 'Ende-zu-Ende verschlüsselt (Mensch direkt)';
	@override String get originMismatchTitle => 'Widersprüchliche Herkunft';
	@override String get originMismatchHint => 'Diese Nachricht trägt sowohl eine Unternehmens-Anwendungsherkunft als auch eine Ende-zu-Ende-verschlüsselte Nutzlast. Sie wird als unverschlüsselte unternehmensgehostete Nachricht angezeigt, nicht als direkt gesendete verschlüsselte Nachricht eines Menschen.';
	@override String get originUnrecognized => 'Herkunftsmarkierung nicht erkannt; unverschlüsselt angezeigt';
	@override String get actionDetails => 'Details';
	@override String get groupTitle => 'Unternehmensgruppe';
	@override String get groupArchivedBadge => 'Archiviert';
	@override String get groupActionArchive => 'Archivieren';
	@override String get groupArchiveTitle => 'Unternehmensgruppe archivieren';
	@override String get groupArchiveHint => 'Archivieren ist einseitig: Die Gruppe wird für alle Unternehmens-Endpunkte unsichtbar und kann nicht wiederhergestellt werden.';
	@override String get groupActionRename => 'Gruppenname ändern';
	@override String get groupRenameHint => 'Neuer Gruppenname';
	@override String get groupMembersTitle => 'Mitglieder und Rollen';
	@override String get groupRoleMember => 'Mitglied';
	@override String get groupRoleGuest => 'Gast';
	@override String get groupRoleAdmin => 'Administrator';
	@override String get groupRoleOwner => 'Eigentümer';
	@override String get groupRoleViceOwner => 'Stellvertreter';
	@override String get groupRoleOwnerLocked => 'Die Eigentümerrolle kann nicht geändert oder von einer Anwendung vergeben werden';
	@override String get groupOverLimit => 'Mitgliederzahl überschreitet das Seitenlimit; Laden gestoppt';
	@override String get groupEmpty => 'Keine Unternehmensgruppen';
	@override String get directoryTitle => 'Mitgliedersuche';
	@override String get directoryHint => 'Nach Name oder Personalnummer suchen';
	@override String get directoryEmpty => 'Keine passenden Mitglieder';
	@override String get directoryBounded => 'Eingeschränktes Verzeichnis: nur seitenweise, kein Vollexport';
	@override String get directoryLoadMore => 'Mehr laden';
	@override String get directoryEnd => 'Ende der Liste';
	@override String get retentionTitle => 'Anhang-Aufbewahrung';
	@override String retentionUntil({required Object time}) => 'Aufbewahrt bis ${time}';
	@override String get holdNone => 'Nicht gesperrt';
	@override String get holdHeld => 'Gesperrt';
	@override String holdReason({required Object reason}) => 'Sperrgrund: ${reason}';
	@override String get purgeLive => 'Nicht gelöscht';
	@override String get purgePurged => 'Gelöscht';
	@override String get retentionNoDelete => 'Governance-Datensätze können nicht gelöscht werden';
	@override String get retentionExtendOnly => 'Aufbewahrung kann nur verlängert, nie verkürzt werden';
	@override String get purgeBlockedHold => 'Eine Sperre ist aktiv; Löschen blockiert';
	@override String get purgeBlockedRetention => 'Aufbewahrungsfrist läuft noch; Löschen blockiert';
	@override String get purgeBlockedPurged => 'Bereits gelöscht; nicht umkehrbar';
	@override String get actionRetry => 'Erneut versuchen';
	@override String get actionSignIn => 'Erneut anmelden';
	@override String get error400Title => 'Anfrage abgelehnt';
	@override String get error400Hint => 'Der übermittelte Inhalt ist nicht zulässig. Bitte prüfen und erneut versuchen.';
	@override String get error401Title => 'Anmeldung abgelaufen';
	@override String get error401Hint => 'Bitte erneut anmelden und wiederholen.';
	@override String get error403Title => 'Anwendung deaktiviert';
	@override String get error403Hint => 'Diese Anwendung oder ihre Organisation ist deaktiviert. Wenden Sie sich an Ihre Administration.';
	@override String get error403ScopeTitle => 'Unzureichender Berechtigungsumfang';
	@override String get error403ScopeHint => 'Dem aktuellen Zugangsnachweis fehlt der für diesen Vorgang nötige Umfang.';
	@override String get error403BoundaryTitle => 'Außerhalb der Unternehmensgrenze';
	@override String get error403BoundaryHint => 'Diese Ressource gehört nicht zum Unternehmen oder Workspace der aktuellen Anwendung.';
	@override String get error404Title => 'Ressource nicht gefunden';
	@override String get error404Hint => 'Die Ressource existiert nicht oder liegt außerhalb Ihres erreichbaren Unternehmensbereichs.';
	@override String get error409Title => 'Vorgangskonflikt';
	@override String get error409Hint => 'Doppelte Übermittlung oder der Zustand hat sich geändert. Aktualisieren und erneut versuchen.';
	@override String get error422IdentityTitle => 'Identität nicht zugeordnet';
	@override String get error422IdentityHint => 'Für dieses Mitglied ist noch keine externe Unternehmensidentität hinterlegt. Bitte zuerst zuordnen.';
	@override String get error429Title => 'Zu viele Anfragen';
	@override String get error429Hint => 'Das Unternehmens-Ratenlimit wurde erreicht. Bitte später erneut versuchen.';
	@override String get error500Title => 'Interner Dienstfehler';
	@override String get error500Hint => 'Der Dienst ist vorübergehend gestört. Bitte später erneut versuchen.';
	@override String get error503Title => 'Dienst nicht verfügbar';
	@override String get error503Hint => 'Das Unternehmens-Sicherheitsgate ist geschlossen. Bitte später erneut versuchen.';
	@override String get errorUnboundTitle => 'Dieser Build hat keinen Unternehmenskanal';
	@override String get errorUnboundHint => 'Unternehmens-Governance-Endpunkte benötigen einen Anwendungsnachweis, der nie im Client eingebettet wird. Bitte den Betreiber einen Kanal anbinden lassen.';
	@override String get errorNetworkTitle => 'Netzwerk nicht verfügbar';
	@override String get errorNetworkHint => 'Bitte Verbindung prüfen und erneut versuchen.';
	@override String get errorUnknownTitle => 'Unbekanntes Ergebnis';
	@override String get errorUnknownHint => 'Der Dienst hat ein unbekanntes Ergebnis geliefert. Bitte später erneut versuchen.';
}

// Path: enterpriseOa
class _Translations$enterpriseOa$de_DE extends Translations$enterpriseOa$zh_CN {
	_Translations$enterpriseOa$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'OA';
	@override String get statusLoading => 'Verbindung zum Unternehmens-Arbeitsbereich…';
	@override String get statusErrorTitle => 'OA kann nicht geladen werden';
	@override String get statusErrorHint => 'Netzwerkfehler oder Dienst vorübergehend nicht verfügbar. Bitte später erneut versuchen.';
	@override String get statusExpiredTitle => 'Anmeldung abgelaufen';
	@override String get statusExpiredHint => 'Der OA-Single-Sign-on-Code ist abgelaufen oder wurde bereits verwendet. Bitte erneut anmelden.';
	@override String get statusLoggedOutTitle => 'Von OA abgemeldet';
	@override String get statusLoggedOutHint => 'Die OA-Sitzung wurde beendet. Eine erneute Single-Sign-on-Anmeldung ist erforderlich.';
	@override String get statusMismatchTitle => 'Navigation aus dem Unternehmens-OA blockiert';
	@override String get statusMismatchHint => 'Es wurde eine nicht autorisierte Adresse erkannt. Das Laden wurde zum Schutz Ihres Kontos gestoppt.';
	@override String statusMismatchBlockedHost({required Object host}) => 'Blockiert: ${host}';
	@override String get statusOa401Title => 'OA-Sitzung nicht autorisiert';
	@override String get statusOa401Hint => 'Der OA-Dienst hat „nicht autorisiert“ zurückgegeben. Bitte erneut anmelden.';
	@override String get actionRetry => 'Erneut versuchen';
	@override String get actionRestartSso => 'Erneut anmelden';
	@override String get webviewSlotHint => 'OA-Seitencontainer (Integration in W3)';
	@override String get badgeDelegated => 'Über OA';
	@override String get markerNoE2ee => 'Unternehmensverwaltet · nicht Ende-zu-Ende-verschlüsselt';
	@override String senderVia({required Object origin}) => 'gesendet über ${origin}';
	@override String get ssoIssuing => 'SSO-Code wird angefordert…';
	@override String ssoCountdown({required Object seconds}) => 'Code ist ${seconds} Sekunden gültig. Bitte bald anmelden.';
	@override String get workbenchTitle => 'Arbeitsbereich';
	@override String get inboundTitle => 'Anmeldung mit OA-Identität';
	@override String get startInbound => 'Identität mit OA bestätigen';
	@override String get accountChoice => 'Verknüpfen Sie ein bestehendes IMBoy-Konto oder erstellen Sie ausdrücklich ein neues.';
	@override String get confirmLink => 'Verknüpfung dieses Kontos bestätigen';
	@override String get useExistingAccount => 'Bei bestehendem IMBoy-Konto anmelden';
	@override String get confirmCreate => 'Erstellung eines neuen IMBoy-Kontos bestätigen';
	@override String get apps => 'Apps';
}

// Path: error
class _Translations$error$de_DE extends Translations$error$zh_CN {
	_Translations$error$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get restartRequired => 'App-Neustart erforderlich';
	@override String get pleaseCheckNetwork => 'Bitte überprüfen Sie Ihre Netzwerkeinstellungen.';
	@override String get networkTroubleshootingStep1 => '1. Telefoneinstellungen öffnen, WLAN eingeschaltet lassen.';
	@override String get networkTroubleshootingStep2 => '2. Einstellungen - Allgemein - Mobilfunkdaten, Schalter eingeschaltet lassen.';
	@override String get networkTroubleshootingStep3 => '3. Keine Verbindung? Prüfen Sie WLAN-Internetzugang oder kontaktieren Sie den Netzbetreiber.';
	@override String get suggestCheckNetwork => 'Überprüfen Sie die Netzwerkeinstellungen.';
	@override String get e2eeErrTimeout => 'Zeitüberschreitung beim Verschlüsseln. Netzwerk prüfen und erneut versuchen.';
	@override String get e2eeErrNetwork => 'Netzwerkfehler beim Verschlüsseln, Nachricht nicht gesendet';
	@override String get e2eeErrPolicyNotReady => 'Die Ende-zu-Ende-Verschlüsselungsrichtlinie ist noch nicht bereit. Bitte später erneut versuchen';
	@override String get liveRoomTitleRequired => 'Titel erforderlich';
}

// Path: group
class _Translations$group$de_DE extends Translations$group$zh_CN {
	_Translations$group$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get enterSameGroup => 'Mit Freunden in der Nähe denselben Gruppenchat beitreten';
	@override String get enterTheGroup => 'Der Gruppe beitreten';
	@override String get groupAlias => 'Mein Spitzname in dieser Gruppe';
	@override String get groupAlbum => 'Gruppenalbum';
	@override String get groupDissolve => 'Gruppe auflösen';
	@override String get groupLeave => 'Gruppe verlassen';
	@override String get groupMembers => 'Gruppenmitglieder';
	@override String get groupName => 'Gruppenname';
	@override String get mutualGroupsWithHer => 'Gemeinsame Gruppen';
	@override String get groupOwner => 'Owner';
	@override String get groupAdmin => 'Admin';
	@override String get groupGuest => 'Ehrengast';
	@override String get setAdmin => 'Als Admin festlegen';
	@override String get selectGroup => 'Gruppe auswählen';
	@override String get sureToDissolveGroup => 'Gruppe wirklich auflösen?';
	@override String get sureToLeaveGroup => 'Gruppe wirklich verlassen?';
	@override String get groupAlbumNameHint => 'Albumname eingeben';
	@override String get groupAlbumRenameTitle => 'Album umbenennen';
	@override String get groupAlbumRenamed => 'Album umbenannt';
	@override String get groupAlbumUnnamed => 'Unbenanntes Album';
	@override String groupAlbumPhotoCount({required Object count}) => '${count} Bilder';
	@override String get groupAlbumPhotoIdMissing => 'Bild-ID fehlt, Details können nicht angezeigt werden';
	@override String get groupAlbumPhotoListTitle => 'Albumbilder';
	@override String groupAlbumPhotoSelectedCount({required Object count}) => '${count} ausgewählt';
	@override String get groupAlbumPhotoEmpty => 'Keine Bilder';
	@override String get groupAlbumPhotoUrlMissing => 'Bildadresse fehlt, kann nicht geöffnet werden';
	@override String get groupAlbumPhotoUrlInvalid => 'Bildadresse ungültig';
	@override String get groupAlbumPhotoDetailTitle => 'Bild-Details';
	@override String get groupAlbumPhotoSetCover => 'Als Cover festlegen';
	@override String get groupAlbumPhotoPrev => 'Zurück';
	@override String get groupAlbumPhotoLikeCount => 'Gefällt-mir';
	@override String get groupAlbumPhotoCommentCount => 'Kommentare';
	@override String get groupAlbumPhotoMyLike => 'Mein Like';
	@override String get groupAlbumPhotoIdLabel => 'Bild-ID';
	@override String get e2eeKeyManagement => 'E2EE-Schlüsselverwaltung';
	@override String get e2eeKeyManagementSubtitle => 'E2EE-Schlüssel sichern, wiederherstellen und verwalten';
	@override String get e2eeTitle => 'Ende-zu-Ende-Verschlüsselung';
	@override String get e2eeEnableConfirm => 'Nach der Aktivierung werden Gruppennachrichten Ende-zu-Ende verschlüsselt und sind nur auf den Geräten der Mitglieder lesbar. Dies kann nicht rückgängig gemacht werden. Aktivieren?';
	@override String get enterGroupChat => 'Zum Gruppenchat';
	@override String get groupCreated => 'Gruppenchat erstellt';
	@override String get groupCreatedSuccess => 'Gruppenchat erstellt. Bitte vervollständigen Sie die Gruppeninfos oder treten Sie direkt bei';
	@override String get groupInfo => 'Gruppenchat-Infos';
	@override String get groupMemberRoleLabel => 'Mitglied';
	@override String get moreActions => 'Weitere Aktionen';
	@override String noMemberWithRole({required Object roleName}) => 'Keine ${roleName} vorhanden';
	@override String get perfectionGroupInfo => 'Gruppeninfos vervollständigen';
	@override String get touchContactAddMember => 'Kontakt antippen, um als Gruppenmitglied hinzuzufügen';
	@override String get transferAndLeave => 'Übertragen und verlassen';
	@override String get sureToTransferAndLeave => 'Du überträgst die Eigentümerschaft und verlässt die Gruppe. Fortfahren?';
	@override String get transferredButLeaveFailed => 'Eigentümerschaft übertragen, aber das Verlassen ist fehlgeschlagen. Bitte erneut versuchen';
	@override String get noEligibleSuccessor => 'Kein Mitglied zum Übertragen verfügbar';
}

// Path: groupCategory
class _Translations$groupCategory$de_DE extends Translations$groupCategory$zh_CN {
	_Translations$groupCategory$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Gruppenkategorien';
	@override String get createCategory => 'Kategorie erstellen';
	@override String get categoryName => 'Kategorie-Name';
	@override String get noCategory => 'Keine Kategorien';
	@override String get deleteCategory => 'Kategorie löschen';
	@override String get deleteCategoryConfirm => 'Diese Kategorie wirklich löschen? Gruppen bleiben erhalten.';
	@override String get categoryDeleted => 'Kategorie gelöscht';
	@override String get renameCategory => 'Kategorie umbenennen';
	@override String get categoryRenamed => 'Kategorie umbenannt';
	@override String get renameFailed => 'Umbenennen fehlgeschlagen. Bitte erneut versuchen.';
	@override String get deleteFailed => 'Löschen fehlgeschlagen. Bitte erneut versuchen.';
	@override String get categoryDetailTip => 'Gruppen dieser Kategorie lassen sich in der Gruppenliste über „In Kategorie verschieben" verwalten';
}

// Path: groupDiscovery
class _Translations$groupDiscovery$de_DE extends Translations$groupDiscovery$zh_CN {
	_Translations$groupDiscovery$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Gruppen entdecken';
	@override String get searchHint => 'Öffentliche Gruppen suchen';
	@override String get allCategories => 'Alle';
	@override String get sortPopular => 'Beliebt';
	@override String get sortNewest => 'Neueste';
	@override String get emptyTitle => 'Noch keine öffentlichen Gruppen. Schauen Sie später wieder vorbei';
	@override String get searchEmpty => 'Keine passenden öffentlichen Gruppen';
}

// Path: groupList
class _Translations$groupList$de_DE extends Translations$groupList$zh_CN {
	_Translations$groupList$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get attrAll => 'Alle';
	@override String get attrOwner => 'Erstellt';
	@override String get attrManager => 'Verwaltet';
	@override String get attrJoin => 'Beigetreten';
	@override String get refresh => 'Aktualisieren';
}

// Path: groupSchedule
class _Translations$groupSchedule$de_DE extends Translations$groupSchedule$zh_CN {
	_Translations$groupSchedule$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Gruppen-Termine';
	@override String get createSchedule => 'Termin erstellen';
	@override String get scheduleTitle => 'Termin-Titel';
	@override String get selectDate => 'Datum wählen';
	@override String get selectTime => 'Uhrzeit wählen';
	@override String get location => 'Ort';
	@override String get noSchedule => 'Keine Termine';
	@override String get startTime => 'Beginn';
	@override String get endTime => 'Ende';
	@override String get participants => 'Teilnehmer';
	@override String get statusCancelled => 'Abgesagt';
	@override String get statusInProgress => 'Läuft';
	@override String get statusNotStarted => 'Nicht begonnen';
	@override String get statusEnded => 'Beendet';
	@override String get cancelSuccess => 'Termin abgesagt';
	@override String get cancelFailed => 'Absagen fehlgeschlagen. Bitte später erneut versuchen.';
	@override String get confirmAttend => 'Teilnehmen';
	@override String get declineAttend => 'Absagen';
	@override String get cancelSchedule => 'Termin absagen';
	@override String get scheduleIdMissing => 'Termin-ID fehlt, Details können nicht angezeigt werden';
	@override String get untitledSchedule => 'Unbenannter Termin';
	@override String get cardViewAndAttend => 'Details ansehen und zusagen';
}

// Path: groupTag
class _Translations$groupTag$de_DE extends Translations$groupTag$zh_CN {
	_Translations$groupTag$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Gruppen-Tags';
	@override String get addTag => 'Tag hinzufügen';
	@override String get tagName => 'Tag-Name';
	@override String get noTag => 'Keine Tags';
	@override String get removeTitle => 'Tag entfernen';
	@override String get removeConfirm => 'Dieses Tag wirklich entfernen?';
}

// Path: groupTask
class _Translations$groupTask$de_DE extends Translations$groupTask$zh_CN {
	_Translations$groupTask$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'To-dos';
	@override String get createTask => 'To-do erstellen';
	@override String get editTask => 'To-do bearbeiten';
	@override String get taskTitle => 'To-don-Titel';
	@override String get taskDescription => 'Beschreibung';
	@override String get deadline => 'Frist';
	@override String get noDeadline => 'Keine Frist';
	@override String get noTask => 'Keine To-don';
	@override String get all => 'Alle';
	@override String get pending => 'Offen';
	@override String get completed => 'Erledigt';
	@override String get taskSubmitted => 'To-do eingereicht';
	@override String get submitTask => 'To-do einreichen';
	@override String get overdue => 'Überfällig';
	@override String daysLeft({required Object days}) => 'Frist in ${days} Tagen';
	@override String hoursLeft({required Object hours}) => 'Frist in ${hours} Std.';
	@override String get dueSoon => 'Frist bald';
	@override String get submitFailed => 'Einreichen fehlgeschlagen. Bitte später erneut versuchen.';
	@override String get pendingReview => 'Prüfung ausstehend';
	@override String get taskIdMissing => 'To-don-ID fehlt, Details können nicht angezeigt werden';
	@override String get taskIdMissingSubmit => 'To-don-ID fehlt, Einreichen nicht möglich';
	@override String publishedAt({required Object time}) => 'Veröffentlicht ${time}';
	@override String completedAt({required Object time}) => 'Abgeschlossen ${time}';
}

// Path: groupVote
class _Translations$groupVote$de_DE extends Translations$groupVote$zh_CN {
	_Translations$groupVote$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Gruppen-Umfrage';
	@override String get createVote => 'Umfrage erstellen';
	@override String get voteTitle => 'Umfrage-Titel';
	@override String get noVote => 'Keine Umfragen';
	@override String get voteEnded => 'Umfrage beendet';
	@override String totalVotes({required Object count}) => '${count} Stimmen gesamt';
	@override String get voteSuccess => 'Abstimmung gespeichert';
	@override String get cancelVoteSuccess => 'Abstimmung zurückgezogen';
	@override String get eachOptionPerLine => 'Eine Option pro Zeile';
	@override String get statusInProgress => 'Läuft';
	@override String get updateVote => 'Umfrage aktualisieren';
	@override String get cancelMyVote => 'Meine Abstimmung zurückziehen';
	@override String get voteIdMissing => 'Umfrage-ID fehlt, Details können nicht angezeigt werden';
	@override String participantCount({required Object count}) => 'Teilnehmer: ${count}';
	@override String get singleChoice => 'Einfachauswahl';
	@override String get multipleChoice => 'Mehrfachauswahl';
	@override String get endVote => 'Abstimmung beenden';
	@override String get alreadyVoted => 'Abgestimmt';
	@override String selectedCount({required Object count}) => '${count} ausgewählt';
	@override String voteCount({required Object count}) => '${count} Stimmen';
}

// Path: main
class _Translations$main$de_DE extends Translations$main$zh_CN {
	_Translations$main$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get totalAssets => 'Gesamtvermögen';
	@override String get album => 'Fotos';
	@override String get appSize => 'App-Größe';
	@override String get arSa => 'Arabisch (Saudi-Arabien)';
	@override String get audio => 'Audio';
	@override String get barcodeFound => 'Strichcode gefunden!';
	@override String get botQianFan => 'QianFan Robot';
	@override String get liveRoomWhipLabel => 'WHIP-Streaming-URL';
	@override String get liveRoomWhepLabel => 'WHEP-Empfangs-URL';
	@override String get cache => 'Cache';
	@override String get camera => 'Kamera';
	@override String changeParam({required Object param}) => '${param} ändern';
	@override String get chooseFromAlbum => 'Aus Album auswählen';
	@override String get clean => 'Bereinigen';
	@override String codeSentToParam({required Object param}) => 'Bestätigungscode an ${param} gesendet';
	@override String get collected => 'Favorisiert';
	@override String get completed => 'Abgeschlossen';
	@override String get copied => 'Kopiert';
	@override String get darkModel => 'Dunkler Modus';
	@override String get deDd => 'Deutsch (Deutschland)';
	@override String get disable => 'Deaktivieren';
	@override String get enUs => 'Amerikanisches Englisch';
	@override String get enable => 'Aktivieren';
	@override String get expired => 'Abgelaufen';
	@override String get e2eeCollectRotating => 'Schlüsselrotation läuft, bitte später erneut versuchen';
	@override String get e2eeCollectUnsupported => 'Server unterstützt Ende-zu-Ende-verschlüsselte Favoriten noch nicht, bitte Server aktualisieren';
	@override String get favorites => 'Favoriten';
	@override String get female => 'Weiblich';
	@override String get followSystem => 'System folgen';
	@override String get frFr => 'Französisch (Frankreich)';
	@override String get from => 'Von';
	@override String get good => 'Sehr gut';
	@override String get hangup => 'Auflegen';
	@override String get iAm => 'Ich bin';
	@override String get itIt => 'Italienisch (Italien)';
	@override String get jaJp => 'Japanisch (Japan)';
	@override String get keepSecret => 'Geheim halten';
	@override String get lastActiveTime => 'Letzte Aktivitätszeit';
	@override String get lastSeenHide => 'Online-Status ausblenden';
	@override String get lastSeenNever => 'Nie online';
	@override String lastSeenWeeksAgo({required Object param}) => 'Vor ${param} Wochen';
	@override String lastSeenExactTime({required Object param}) => 'Zuletzt online ${param}';
	@override String get licenseAgreement => 'Softwarelizenz- und Dienstleistungsvereinbarung';
	@override String get loudspeaker => 'Lautsprecher';
	@override String get makeYourselfInvisible => 'Unsichtbar werden';
	@override String get makeYourselfVisible => 'Sichtbar werden';
	@override String get male => 'Männlich';
	@override String get manage => 'Verwalten';
	@override String get markStar => 'Favorit';
	@override String get multiSelect => 'Mehrfachauswahl';
	@override String get myFavorites => 'Meine Favoriten';
	@override String get myLive => 'Mein Live-Stream';
	@override String get name => 'Name';
	@override String numUnit({required Object param}) => '${param} Stück';
	@override String get openInBrowser => 'Im Browser öffnen';
	@override String get or => 'Oder';
	@override String get otherParty => 'Gegenüber';
	@override String get packageSize => 'Paketgröße';
	@override String get peerHasHungUp => 'Gesprächspartner hat aufgelegt';
	@override String get play => 'Abspielen';
	@override String pleaseInputParam({required Object param}) => 'Bitte ${param} eingeben';
	@override String get pleaseSelect => 'Bitte auswählen';
	@override String get quote => 'Zitat';
	@override String get recentlyUsed => 'Kürzlich verwendet';
	@override String get releaseEnd => 'Zum Beenden loslassen';
	@override String get memberDetail => 'Mitgliederdetails';
	@override String get replied => 'Geantwortet';
	@override String get ringing => 'Klingelt...';
	@override String get ruRu => 'Russisch (Russland)';
	@override String selectedCount({required Object count}) => 'Ausgewählt (${count})';
	@override String get selected => 'Ausgewählt';
	@override String get sent => 'Gesendet';
	@override String get sentByMe => 'Von mir gesendet';
	@override String setParam({required Object param}) => '${param} einstellen';
	@override String get setting => 'Einstellungen';
	@override String get siginQ => 'Bereits ein Konto?';
	@override String get source => 'Quelle';
	@override String get speakingTooShort => 'Sprechzeit zu kurz';
	@override String get speed => 'Geschwindigkeit';
	@override String get stillNeeded => 'Noch benötigt';
	@override String get storageSpace => 'Speicherplatz';
	@override String get text => 'Text';
	@override String get thisWeek => 'Diese Woche';
	@override String get titleMine => 'Ich';
	@override String get tooBad => 'Zu schlecht';
	@override String get tryAgainQ => 'Nochmal versuchen?';
	@override String get type => 'Typ';
	@override String get unanswered => 'Unbeantwortet';
	@override String get unnamed => 'Unbenannt';
	@override String get usedSpace => 'Verwendeter Speicherplatz';
	@override String get you => 'Sie';
	@override String get zhCn => 'Vereinfachtes Chinesisch';
	@override String get zhHant => 'Traditionelles Chinesisch';
	@override String get bound => 'Gebunden';
	@override String get correct => 'Korrekt';
	@override String get pendingInput => 'Eingabe ausstehend';
	@override String get lengthCheck => 'Längenprüfung';
	@override String get bugReport => 'Fehlerbericht';
	@override String get deleting => 'Wird gelöscht...';
	@override String get publish => 'Veröffentlichen';
	@override String get privacyPolicy => 'Datenschutzrichtlinie';
	@override String get termsOfService => 'Nutzungsbedingungen';
	@override String get saving => _root.common.loading;
	@override String get systemDefault => 'Systemstandard';
	@override String get gradientBlue => 'Verlauf Blau';
	@override String get gradientPurple => 'Verlauf Lila';
	@override String get copiedToClipboard => 'In die Zwischenablage kopiert';
	@override String get destroyTime => 'Zerstörungszeit';
	@override String get previewEffect => 'Vorschau-Effekt';
	@override String get thisIsTitleText => 'Dies ist Titeltext';
	@override String get thisIsAuxiliaryText => 'Dies ist Hilfstext';
	@override String get toBeCompleted => 'Noch zu vervollständigen';
	@override String get availableCount => 'Verfügbar';
	@override String get mostUsed => 'Am häufigsten verwendet';
	@override String get school => 'Schule';
	@override String get hobbiesAndInterests => 'Hobbys & Interessen';
	@override String get interests => 'Interessen';
	@override String get selectFromAlbum => 'Aus Album auswählen';
	@override String get volumeUp => 'Lautstärke erhöhen';
	@override String get volumeDown => 'Lautstärke verringern';
	@override String fastRewind({required Object seconds}) => 'Schnell zurück ${seconds} Sekunden';
	@override String get pleaseTryAgain => 'Bitte versuchen Sie es erneut';
	@override String get secret => 'Geheim';
	@override String get takePhoto => 'Foto aufnehmen';
	@override String get deletingInProgressPleaseWait => 'Wird gelöscht, bitte warten...';
	@override String get collecting => 'Wird favorisiert...';
	@override String get user => 'Benutzer';
	@override String get recommended => 'Empfohlen';
	@override String get larger => 'Größer';
	@override String get fillIn => 'Ausfüllen';
	@override String get msgProtectedByComplianceKey => 'Nachricht durch Compliance-Schlüssel geschützt';
	@override String inviterLabel({required Object uid}) => 'Eingeladen von: ${uid}';
	@override String inviteeLabel({required Object uid}) => 'Eingeladener: ${uid}';
	@override String get mySentTab => 'Gesendet';
	@override String get reject => 'Ablehnen';
	@override String get myOrders => 'Bestellungen';
	@override String get purchaseUnlockHint => 'Nach Kauf werden Verlauf und neue Nachrichten freigeschaltet.';
	@override String get payingDots => 'Zahlung...';
	@override String get purchaseAndUnlock => 'Jetzt kaufen & freischalten';
	@override String get orderDetail => 'Bestelldetails';
	@override String orderAmountLabel({required Object currency, required Object amount}) => 'Betrag: ${currency} ${amount}';
	@override String channelPriceLabel({required Object currency, required Object amount}) => 'Preis: ${currency} ${amount}';
	@override String get e2eeKeyRecoveryTitle => 'E2EE-Schlüsselverwaltung';
	@override String get e2eeRecoveryMethods => 'Wiederherstellungsmethoden';
	@override String get e2eeDangerousOps => 'Kritische Aktionen';
	@override String get e2eeKeyIdLabel => 'Schlüssel-ID';
	@override String get e2eeWarnIrreversible => '• Vorgang nicht umkehrbar';
	@override String get e2eeWarnNeedRestoreOrNew => '• Aus Backup wiederherstellen oder neuen Schlüssel erstellen';
	@override String get gotIt => 'Verstanden';
	@override String get webQRLoggingIn => 'Anmeldung...';
	@override String get webQRExpired => 'QR-Code abgelaufen';
	@override String get webQRRefresh => 'QR-Code aktualisieren';
	@override String get webSwitchToQR => 'Per QR-Code anmelden';
	@override String get e2eeErrDefault => 'E2EE fehlgeschlagen, Nachricht nicht gesendet';
	@override String get e2eeErrPeerDeviceNotReady => 'Die Sicherheitseinrichtung einiger Mitglieder ist nicht abgeschlossen, Nachricht nicht gesendet; bitte später erneut versuchen';
	@override String get liveRoomTitleLabel => 'Livestream-Titel';
	@override String get liveRoomTitleHint => 'Livestream-Titel eingeben';
	@override String get lightModel => 'Heller Modus';
	@override String get safetyNumberTitle => 'Sicherheitscode-Verifizierung';
	@override String get safetyNumberHint => 'Vergleichen Sie den Sicherheitscode persönlich oder telefonisch mit der anderen Person. Bei Übereinstimmung wird Ihre Kommunikation nicht abgehört; bei Abweichung beenden Sie sofort das Gespräch und verifizieren Sie die Identität über einen anderen Kanal. Der Verifizierungsstatus wird nur auf diesem Gerät gespeichert.';
	@override String get safetyNumberCopy => 'Kopieren';
	@override String get safetyNumberCopied => 'Kopiert';
	@override String get safetyNumberMarkVerified => 'Als verifiziert markieren';
	@override String get safetyNumberMarkedVerified => 'Als verifiziert markiert';
	@override String get safetyNumberNoDevices => 'Die Gegenseite hat Ende-zu-Ende-Verschlüsselung noch nicht aktiviert';
	@override String get safetyNumberPeerDevice => 'Gerät der Gegenseite';
	@override String get safetyNumberReportRejected => 'Der Server hat das Verifizierungsereignis abgelehnt (Signatur/Gültigkeit passt nicht), nicht markiert';
	@override String get safetyNumberReportUnavailable => 'Geräteinformationen nicht verfügbar, nicht gemeldet';
	@override String get safetyNumberVerified => '✓ Verifiziert';
	@override String get safetyNumberNotVerified => 'Nicht verifiziert';
	@override String safetyNumberDeviceCount({required Object count}) => '${count} Gerät(e)';
	@override String get safetyNumberReporting => 'Verifizierungsergebnis wird gemeldet...';
	@override String get safetyNumberVerifyFailed => 'Sicherheitscode konnte nicht abgerufen werden. Bitte später erneut versuchen';
	@override String get complianceKeyInfoTitle => 'Compliance-Audit-Schlüssel';
	@override String get complianceKeyInfoAlgorithm => 'Algorithmus';
	@override String get complianceKeyInfoChangedWarning => '⚠️ Der vom Server bereitgestellte öffentliche Compliance-Schlüssel stimmt nicht mit dem lokalen Pinning überein! Falls dies keine beabsichtigte Rotation durch den Administrator ist, kontaktieren Sie sofort den Administrator und senden Sie keine verschlüsselten Nachrichten.';
	@override String get complianceKeyInfoFetchedAt => 'Abgerufen am';
	@override String get complianceKeyInfoFingerprint => 'Öffentlicher Schlüssel-Fingerabdruck';
	@override String get complianceKeyInfoHint => 'Der Compliance-Audit-Schlüssel dient der doppelten Verschlüsselung im compliance_e2ee-Modus. Weicht der obige Fingerabdruck vom Fingerabdruck ab, den der Administrator veröffentlicht hat, wurde der Server möglicherweise manipuliert.';
	@override String get complianceKeyInfoKeyId => 'Schlüssel-ID';
	@override String get complianceKeyInfoLocalPin => 'Lokales Pinning (TOFU)';
	@override String get complianceKeyInfoPinnedAt => 'Gepinnt am';
	@override String get complianceKeyInfoPinnedNone => 'Noch nicht gepinnt (wird beim nächsten Abruf automatisch gepinnt)';
	@override String get complianceKeyInfoRefreshFailed => 'Abruf fehlgeschlagen. Bitte Netzwerk prüfen und erneut versuchen';
	@override String get complianceKeyInfoServerKey => 'Vom Server bereitgestellter öffentlicher Schlüssel';
	@override String get e2eeErrComplianceChanged => 'Compliance-Audit-Schlüssel hat sich geändert, Nachricht nicht gesendet. Bitte Rotation bestätigen und erneut versuchen';
	@override String get e2eeErrComplianceUnavailable => 'Compliance-Schlüssel derzeit nicht verfügbar, Nachricht nicht gesendet. Bitte später erneut versuchen';
	@override String get e2eeErrComplianceExpired => 'Der Compliance-Schlüssel ist abgelaufen. Bitte kontaktieren Sie den Administrator';
	@override String get complianceKeyRotationConfirmed => 'Compliance-Schlüsselrotation bestätigt, Nachricht kann erneut gesendet werden';
	@override String get complianceKeyRotationNoPending => 'Keine ausstehende Schlüsseländerung zu bestätigen';
	@override String get e2eeErrDeviceNotReady => 'Sicherheitsinitialisierung dieses Geräts nicht abgeschlossen. Bitte abmelden, neu anmelden und erneut versuchen';
	@override String get e2eeErrProtocolMismatch => 'Verschlüsselungsprotokoll-Konfiguration fehlerhaft. Bitte App aktualisieren und erneut versuchen';
	@override String get e2eeErrPeerSuiteUnsupported => 'Das Gerät der Gegenseite unterstützt die erforderliche Verschlüsselungssuite nicht, Nachricht nicht gesendet. Bitte die Gegenseite zum App-Update auffordern und erneut versuchen';
	@override String get e2eeErrSessionExportFailed => 'Gruppensitzungsschlüssel konnte nicht erstellt werden. Bitte später erneut versuchen';
	@override String get complianceKeyNotConfigured => 'Für diese Bereitstellung ist kein Compliance-Audit-Schlüssel konfiguriert';
	@override String get mineContent => 'Meine Inhalte';
	@override String get mineCommonEntries => 'Schnellzugriff';
	@override String get mineManagementSupport => 'Verwaltung & Hilfe';
	@override String get mineSettingsSupport => 'Einstellungen & Hilfe';
	@override String get mineStorageUsage => 'Speichernutzung';
}

// Path: mention
class _Translations$mention$de_DE extends Translations$mention$zh_CN {
	_Translations$mention$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get mentionAll => 'Alle';
	@override String get mentionAllHint => 'Alle Gruppenmitglieder benachrichtigen';
	@override String get noMatchedMember => 'Keine passenden Mitglieder';
	@override String get title => '@Erwähnungen';
	@override String get noMention => 'Keine @Erwähnungen';
	@override String get allRead => 'Alle gelesen';
	@override String get mentionAllDenied => 'Nur Administratoren können @alle verwenden';
	@override String get navInfoMissing => 'Nachrichtenposition fehlt, Sprung nicht möglich';
	@override String get pickButtonTooltip => 'Mitglied erwähnen';
}

// Path: momentFriendPicker
class _Translations$momentFriendPicker$de_DE extends Translations$momentFriendPicker$zh_CN {
	_Translations$momentFriendPicker$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get confirm => 'Fertig';
	@override String confirmWithCount({required Object count}) => 'Fertig (${count})';
	@override String selectedCount({required Object count}) => '${count} ausgewählt';
	@override String get emptyFriends => 'Keine Freunde';
	@override String get tagLoadFailed => 'Tags konnten nicht geladen werden';
	@override String get searchHint => 'Freunde durchsuchen';
}

// Path: momentNotify
class _Translations$momentNotify$de_DE extends Translations$momentNotify$zh_CN {
	_Translations$momentNotify$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Interaktionen';
	@override String get emptyTitle => 'Keine neuen Benachrichtigungen';
	@override String get emptyHint => '„Gefällt mir" und Kommentare von Freunden erscheinen hier';
	@override String get actionLike => 'hat Ihren Moment gelikt';
	@override String get actionComment => 'hat kommentiert';
	@override String get markAllRead => 'Alle gelesen';
	@override String get clearAll => 'Alle löschen';
	@override String get clearConfirmTitle => 'Alle Benachrichtigungen löschen?';
	@override String get clearConfirmMessage => 'Kann nicht rückgängig gemacht werden';
	@override String get confirm => 'OK';
	@override String get cancel => 'Abbrechen';
	@override String get delete => 'Löschen';
	@override String get loadFailed => 'Laden fehlgeschlagen. Bitte später erneut versuchen.';
}

// Path: organization
class _Translations$organization$de_DE extends Translations$organization$zh_CN {
	_Translations$organization$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override late final _Translations$organization$common$de_DE common = _Translations$organization$common$de_DE._(_root);
	@override late final _Translations$organization$home$de_DE home = _Translations$organization$home$de_DE._(_root);
	@override late final _Translations$organization$detail$de_DE detail = _Translations$organization$detail$de_DE._(_root);
	@override late final _Translations$organization$members$de_DE members = _Translations$organization$members$de_DE._(_root);
	@override late final _Translations$organization$invitations$de_DE invitations = _Translations$organization$invitations$de_DE._(_root);
	@override late final _Translations$organization$departments$de_DE departments = _Translations$organization$departments$de_DE._(_root);
	@override late final _Translations$organization$picker$de_DE picker = _Translations$organization$picker$de_DE._(_root);
	@override late final _Translations$organization$inviteColleagues$de_DE inviteColleagues = _Translations$organization$inviteColleagues$de_DE._(_root);
	@override late final _Translations$organization$inviteQr$de_DE inviteQr = _Translations$organization$inviteQr$de_DE._(_root);
	@override late final _Translations$organization$directory$de_DE directory = _Translations$organization$directory$de_DE._(_root);
	@override late final _Translations$organization$memberDetail$de_DE memberDetail = _Translations$organization$memberDetail$de_DE._(_root);
	@override late final _Translations$organization$manage$de_DE manage = _Translations$organization$manage$de_DE._(_root);
	@override late final _Translations$organization$contactEntry$de_DE contactEntry = _Translations$organization$contactEntry$de_DE._(_root);
	@override late final _Translations$organization$hub$de_DE hub = _Translations$organization$hub$de_DE._(_root);
	@override late final _Translations$organization$wsMembers$de_DE wsMembers = _Translations$organization$wsMembers$de_DE._(_root);
	@override late final _Translations$organization$tools$de_DE tools = _Translations$organization$tools$de_DE._(_root);
	@override late final _Translations$organization$chart$de_DE chart = _Translations$organization$chart$de_DE._(_root);
	@override late final _Translations$organization$experienceUi$de_DE experienceUi = _Translations$organization$experienceUi$de_DE._(_root);
}

// Path: passport
class _Translations$passport$de_DE extends Translations$passport$zh_CN {
	_Translations$passport$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get loginHistoryToggle => 'Anmeldeverlauf anzeigen';
	@override String get hintEmail => 'Bitte E-Mail eingeben';
	@override String get hintMobile => 'Bitte Mobilfunknummer eingeben';
	@override String get hintPassword => 'Bitte Passwort eingeben';
	@override String get hintVerifyCode => 'Bitte Bestätigungscode eingeben';
	@override String get getVerifyCode => 'Code anfordern';
	@override String get oneKeyLogin => 'Schnellanmeldung';
	@override String get qrCodeExpired => 'QR-Code abgelaufen, bitte neu scannen';
	@override String get qrCodeUsed => 'Dieser QR-Code wurde bereits verwendet';
	@override String get qrConnecting => 'Verbindung wird hergestellt...';
	@override String get qrLoginAction => 'Anmeldung bestätigen';
	@override String get qrLoginCancelled => 'Anmeldung wurde abgebrochen';
	@override String get qrLoginCancelledByMe => 'Sie haben die Anmeldung abgebrochen';
	@override String get qrLoginConfirming => 'Anmeldung läuft...';
	@override String get qrLoginSuccess => 'Angemeldet';
	@override String get qrWebLoginDesc => 'Bitte bestätigen Sie die Anmeldung dieses Kontos im Web';
	@override String get qrWebLoginTitle => 'Web-Anmeldung bestätigen';
	@override String get alipayNotSupportedWeb => 'Alipay-Anmeldung wird im Web nicht unterstützt';
	@override String get oneKeyNotSupportedWeb => 'One-Tap-Login wird im Web nicht unterstützt';
	@override String get oneKeyInitFailed => 'One-Tap-Login konnte nicht initialisiert werden, bitte später erneut versuchen';
	@override String get oneKeyNoSimCard => 'Das aktuelle Netzwerk wird nicht unterstützt oder das Handy hat keine SIM-Karte';
	@override String get cannotGetScreenSize => 'Bildschirmgröße konnte nicht ermittelt werden';
	@override String get oneKeyFailedRetry => 'One-Tap-Login fehlgeschlagen, bitte Netzwerk prüfen und erneut versuchen';
}

// Path: splash
class _Translations$splash$de_DE extends Translations$splash$zh_CN {
	_Translations$splash$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get slogan => 'Frei kommunizieren.';
}

// Path: talkRecord
class _Translations$talkRecord$de_DE extends Translations$talkRecord$zh_CN {
	_Translations$talkRecord$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get uploadProgressRegister => 'Upload wird vorbereitet';
	@override String get uploadProgressUpload => 'Audio wird hochgeladen';
	@override String get uploadProgressConfirm => 'Audio wird bestätigt';
	@override String get uploadProgressSubmitting => 'Speicherung wird übermittelt';
	@override String get uploadProgressCompleted => 'Übermittelt; Audioverarbeitung ausstehend';
	@override String get uploadProgressFailed => 'Upload unvollständig; erneut versuchen';
	@override String uploadProgressParts({required Object confirmed, required Object total}) => 'Bestätigte Teile: ${confirmed}/${total}';
	@override String get aiServicesTitle => 'KI-Dienste';
	@override String get aiServicesSubtitle => 'Verwende eigene API-Konten. Die Anbieter berechnen die Nutzung.';
	@override String get aiMinimaxTitle => 'MiniMax';
	@override String get aiZhipuTitle => 'Zhipu GLM-5.3-Flash';
	@override String get aiMinimaxPurpose => 'Audiotranskription und vorläufige Sprecherlabels';
	@override String get aiZhipuPurpose => 'Entwürfe für Zusammenfassungen, Entscheidungen und Aufgaben';
	@override String get aiConfigured => 'Auf diesem Gerät eingerichtet';
	@override String get aiNotConfigured => 'Nicht eingerichtet';
	@override String get aiLoading => 'Gerätekonfiguration wird gelesen…';
	@override String get aiDeviceOnlyNotice => 'Schlüssel werden nur für dieses Konto auf diesem Gerät verschlüsselt gespeichert. Kein Upload zu IMBoy, kein Cloud-Backup und keine Geräteübertragung. Auf neuen Geräten erneut eingeben.';
	@override String get aiEnterprisePolicyNotice => 'Ein gespeicherter Schlüssel erlaubt noch keine externe Verarbeitung. Unternehmensaufnahmen erfordern die Freigabe der Unternehmensrichtlinie und die Zustimmung zu jeder Verarbeitung.';
	@override String get aiMaxNotice => 'Nutzt die separat berechnete allgemeine Zhipu-API. Ein jährlicher Coding Plan Max deckt diese Nutzung nicht automatisch ab. Transkripte werden an Zhipu gesendet.';
	@override String get aiAudioExternalNotice => 'Für Transkriptionen wird Audio an MiniMax gesendet; Gebühren sind möglich. Pro Anfrage gelten höchstens 500 Sekunden und 50 MB. Der Ablauf prüft und teilt Audio entsprechend.';
	@override String get aiValidationNotice => 'Speichern prüft den Schlüssel nicht und sendet weder Audio noch Text. Eine echte Prüfung kann kostenpflichtig sein und erfordert eine gesonderte Bestätigung.';
	@override String get aiAccountChanged => 'Konto oder Bereitstellung wurde geändert. Gehe zurück und öffne die Seite erneut. Die Eingabe wurde gelöscht.';
	@override String get aiCredentialChanged => 'Die Gerätekonfiguration wurde geändert oder ist unvollständig. Schlüssel erneut eingeben und speichern oder zurückgehen und erneut versuchen.';
	@override String get aiInvalidKey => 'Gib 16–4096 ASCII-Zeichen ohne Leerzeichen, Zeilenumbrüche oder Steuerzeichen ein.';
	@override String get aiStorageFailed => 'Der sichere Gerätespeicher konnte nicht gelesen oder beschrieben werden. Konfiguration unbestätigt. Erneut versuchen; keine Speicherung als Klartext.';
	@override String get aiUnsupportedPlatform => 'Der sichere Gerätespeicher ist auf dieser Plattform noch nicht geprüft. Schlüssel können nicht gespeichert werden.';
	@override String get aiKeyPlaceholder => 'API-Schlüssel eingeben';
	@override String get aiReplacePlaceholder => 'Neuen API-Schlüssel eingeben; gespeicherte Schlüssel werden nie vorbefüllt';
	@override String get aiSaveAction => 'Auf diesem Gerät speichern';
	@override String get aiReplaceAction => 'Geräteschlüssel ersetzen';
	@override String get aiDeleteAction => 'Geräteschlüssel löschen';
	@override String get aiSaving => 'Wird gespeichert…';
	@override String get aiSaved => 'Auf diesem Gerät gespeichert. Der Schlüssel wurde nicht geprüft.';
	@override String get aiDeleted => 'Gerätekonfiguration gelöscht. Aufnahmen und vorhandene Ergebnisse bleiben erhalten.';
	@override String get aiReplaceTitle => 'Geräteschlüssel ersetzen?';
	@override String get aiReplaceNotice => 'Ersetzt nur die Einstellung dieses Dienstes für das aktuelle Konto auf diesem Gerät. Andere Konten und gespeicherte Aufnahmen bleiben unverändert.';
	@override String get aiDeleteTitle => 'Geräteschlüssel löschen?';
	@override String get aiDeleteNotice => 'Stoppt neue Anfragen an diesen Dienst. Aufnahmen und Ergebnisse bleiben erhalten. Bereits an den Anbieter gesendete Anfragen können nicht zurückgerufen werden.';
	@override String get aiCancel => 'Abbrechen';
	@override String get aiDoubaoTitle => 'Doubao Speech 2.0';
	@override String get aiDoubaoPurpose => 'Audiotranskription und temporäre Sprecherlabels';
	@override String get aiDoubaoExternalNotice => 'Audio wird zur Transkription an Volcengine Doubao Speech gesendet. Anbietergebühren können anfallen. API-Key nur auf diesem Gerät; MiniMax-Keys werden nicht übernommen.';
	@override String get aiDoubaoPendingNotice => 'Die Doubao-Transkription ist noch nicht angebunden. Nur Geräteeinstellungen können gespeichert werden. Speichern prüft keine Verbindung und aktiviert keine Transkription.';
	@override String get aiProviderPending => 'Der Anbieter verarbeitet noch. Fortschritt gespeichert. Später nur abfragen; Audio wird nicht erneut gesendet.';
	@override String get aiProviderCancel => 'Transkription stoppen';
	@override String get aiProviderCancelNotice => 'Widerruft IMBoy-Zugriff und Vorgangsrechte. Anbieter-Stopp oder Erstattung werden nicht garantiert.';
	@override String get aiProviderResubmit => 'Audio erneut senden';
	@override String get aiProviderResubmitNotice => 'Erstellt eine neue Transkription; doppelte Gebühren sind möglich. Der ursprüngliche Auftrag bleibt. Erneut senden und dieser Verarbeitung zustimmen?';
	@override String get aiProviderCancelled => 'Transkription gestoppt. Vorhandenes Audio bleibt erhalten.';
	@override String get aiProviderResumePreparation => 'Transkription weiter vorbereiten';
	@override String get aiProviderResumeNotice => 'Der ursprüngliche Auftrag wurde noch nicht übermittelt. Audioquelle mit aktuellen Rechten und Einwilligung erneut vorbereiten.';
}

// Path: welcome
class _Translations$welcome$de_DE extends Translations$welcome$zh_CN {
	_Translations$welcome$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get step1Title => 'Einfache Verbindung';
	@override String get step1Desc => 'Erleben Sie die Freude nahtloser Kommunikation. Jederzeit, überall.';
	@override String get step2Title => 'Sicher & Privat';
	@override String get step2Desc => 'Ende-zu-Ende-Verschlüsselung Hält Ihre persönlichen Momente streng vertraulich.';
	@override String get step3Title => 'Bereit zum Erkunden?';
	@override String get step3Desc => 'Treten Sie einer lebendigen Gemeinschaft bei. Lassen Sie das Gespräch beginnen!';
	@override String get next => 'Weiter';
	@override String get getStarted => 'Loslegen';
	@override String get skip => 'Überspringen';
}

// Path: workspace
class _Translations$workspace$de_DE extends Translations$workspace$zh_CN {
	_Translations$workspace$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get navOverview => 'Übersicht';
	@override String get navProjects => 'Projekte';
	@override String get navChannels => 'Kanäle';
	@override String get navGroups => 'Gruppen';
	@override String get pickerTitle => 'Mein Arbeitsbereich';
	@override String get switchWorkspace => 'Arbeitsbereich wechseln';
	@override String get pickerEmptyTitle => 'Noch kein Arbeitsbereich';
	@override String get pickerEmptySubtitle => 'Erstellen Sie einen Arbeitsbereich und starten Sie in 3 Minuten die Teamarbeit (Announcements-Kanal und General-Gruppe werden automatisch erstellt)';
	@override String get archivedBadge => 'Archiviert';
	@override String get emptyNoWorkspace => 'Bitte zuerst einen Arbeitsbereich auswählen oder erstellen';
	@override String get experienceModePersonal => 'Persönlich';
	@override String get switchToPersonal => 'Zum persönlichen Modus wechseln';
	@override String get createTitle => 'Arbeitsbereich erstellen';
	@override String get createDesc => 'Mit einer Erstellung wird alles automatisch angelegt: Arbeitsbereich, Sie (Owner als Arbeitsbereich-Mitglied), Announcements-Kanal und General-Gruppe. Alles erfolgreich oder vollständiger Rollback.';
	@override String get createNameLabel => 'Arbeitsbereichsname';
	@override String get createNameHint => 'z. B. Website-Relaunch-Team';
	@override String get createNameRequired => 'Arbeitsbereichsname darf nicht leer sein';
	@override String get createSubmit => 'Erstellen';
	@override String get createEntry => 'Arbeitsbereich erstellen';
	@override String get createSuccess => 'Arbeitsbereich erstellt';
	@override String get createIdempotentHit => 'Arbeitsbereich mit diesem Namen existiert bereits, wird direkt geöffnet';
	@override String get createTemplateTitle => 'Wird automatisch initialisiert';
	@override String get createTemplateChannel => 'Announcements-Kanal (Sie werden Kanal-Herausgeber und Abonnent)';
	@override String get createTemplateGroup => 'General-Gruppe (Sie werden Gruppenmitglied)';
	@override String get createTemplateOwner => 'Sie werden Arbeitsbereich-Owner (Arbeitsbereich-Mitglied)';
	@override String get overviewTitle => 'Übersicht';
	@override String get overviewResources => 'Ressourcenüberblick';
	@override String get overviewPinnedContent => 'Angepinnte Kanalinhalte';
	@override String get overviewPinnedEmpty => 'Noch keine angepinnten Kanalinhalte; Gruppenankündigungen werden hier nicht gebündelt (sie gehören zu den einzelnen Gruppen)';
	@override String get overviewRecentFiles => 'Neueste Dateien';
	@override String get overviewRecentFilesEmpty => 'Zuletzt hochgeladene Dateien erscheinen hier; Anhänge sind auch in den einzelnen Kanälen sichtbar';
	@override String get membersTitle => 'Arbeitsbereich-Mitglieder';
	@override String membersCountLabel({required Object count}) => '${count} Mitglieder';
	@override String get membersEmpty => 'Keine Arbeitsbereich-Mitglieder';
	@override String get membersEmptySubtitle => 'Laden Sie registrierte Nutzer als Arbeitsbereich-Mitglieder ein (Owner / Member / Guest)';
	@override String get membersViewAll => 'Alle anzeigen';
	@override String get projectsEmptyTitle => 'Noch keine Projekte';
	@override String get projectsEmptySubtitle => 'Projekte dienen der Verfolgung klarer Lieferziele; gilt ebenso für Community-Arbeitsbereiche mit nur Kanälen und Gruppen';
	@override String get channelsEmptyTitle => 'Noch keine Arbeitsbereich-Kanäle';
	@override String get channelsEmptySubtitle => 'Kanäle dienen der laufenden Veröffentlichung von Inhalten (Ankündigungen/Material); für Diskussionen bitte in die Gruppen';
	@override String channelTileSubtitle({required Object count}) => '${count} Abonnenten';
	@override String get channelDetailTitle => 'Kanal';
	@override String get groupsEmptyTitle => 'Noch keine Arbeitsbereich-Gruppen';
	@override String get groupsEmptySubtitle => 'Gruppen sind der Echtzeit-Diskussionsraum im Arbeitsbereich (einziger Einstieg für Chats)';
	@override String groupTileSubtitle({required Object count}) => '${count} Gruppenmitglieder';
	@override String get inviteTitle => 'Arbeitsbereich-Mitglieder einladen';
	@override String get inviteDesc => 'Nur registrierte Nutzer können eingeladen werden; der Arbeitsbereich-Beitritt umfasst weder Gruppe noch Kanal-Abo – gleichzeitig der General-Gruppe beitreten und eine Announcements-Kanal-Einladung senden ist möglich';
	@override String get inviteSearchHint => 'Nach Nutzername / Nutzer-ID suchen';
	@override String get inviteEntry => 'Arbeitsbereich-Mitglieder einladen';
	@override String get inviteJoinGroupOption => 'Gleichzeitig der General-Gruppe beitreten (als Gruppenmitglied)';
	@override String get inviteSubscribeChannelOption => 'Gleichzeitig eine Announcements-Kanal-Einladung senden';
	@override String get inviteOptionUnavailable => 'Zugehörige Ressource nicht gefunden, diese Option ist nicht verfügbar';
	@override String get inviteSubmit => 'Einladung senden';
	@override String get inviteResultsTitle => 'Ergebnisse (drei unabhängige)';
	@override String get inviteResultWorkspace => 'Dem Arbeitsbereich beigetreten (als Arbeitsbereich-Mitglied)';
	@override String get inviteResultGroup => 'Der General-Gruppe beigetreten (als Gruppenmitglied)';
	@override String get inviteResultChannel => 'Announcements-Kanal-Einladung gesendet (nach Annahme wird der Empfänger Abonnent)';
	@override String get resultIdle => 'Nicht ausgeführt';
	@override String get resultRunning => 'Läuft';
	@override String get resultSuccess => 'Erfolgreich';
	@override String get resultFailed => 'Fehlgeschlagen';
	@override String get joinEntry => 'Arbeitsbereich beitreten';
	@override String get joinByTeamCode => 'Arbeitsbereich per Teamcode beitreten';
	@override String get joinTitle => 'Arbeitsbereich beitreten';
	@override String get joinDesc => 'Geben Sie den Team-Code ein, um dem Arbeitsbereich beizutreten';
	@override String get joinCodeLabel => 'Team-Code';
	@override String get joinCodeHint => '8 Zeichen, Großbuchstaben oder Ziffern';
	@override String get joinSubmit => 'Beitreten';
	@override String joinSuccess({required Object name}) => '„${name}“ beigetreten';
	@override String get joinAlreadyMember => 'Sie sind bereits in diesem Arbeitsbereich';
	@override String get joinInvalidCode => 'Team-Code ungültig oder abgelaufen';
	@override String get joinExpiredCode => 'Team-Code abgelaufen';
	@override String get inviteCodeSectionTitle => 'Einladung per Team-Code';
	@override String get inviteCodeGenerate => 'Team-Code generieren';
	@override String get inviteCodeCopy => 'Kopieren';
	@override String get inviteCodeRevoke => 'Widerrufen';
	@override String inviteCodeExpiresAt({required Object expiresAt}) => 'Gültig bis ${expiresAt}';
	@override String get roleOwner => 'Owner';
	@override String get roleMember => 'Member';
	@override String get roleGuest => 'Guest';
	@override String removeMemberTitle({required Object name}) => 'Arbeitsbereich-Mitglied ${name} entfernen';
	@override String get removeMemberDesc => 'Nach dem Entfernen erlischt der Arbeitsbereich-Zugang; hat die Person noch offene Aufgaben oder leitet Projekte, liefert der Server eine Konfliktliste und bricht das Entfernen ab';
	@override String get removeMemberConfirm => 'Entfernen bestätigen';
	@override String changeRoleTitle({required Object name}) => 'Arbeitsbereich-Rolle von ${name} ändern';
	@override String transferTitle({required Object name}) => 'Haupt-Owner an ${name} übertragen';
	@override String get transferDesc => 'Nach der Übertragung werden Sie normales Arbeitsbereich-Mitglied (Member), die andere Person erhält die volle Kontrolle';
	@override String get transferConfirm => 'Übertragung bestätigen';
	@override String get governanceTitle => 'Arbeitsbereich-Governance';
	@override String get brandingEntry => 'Branding (Name / Logo / Hauptfarbe)';
	@override String get archiveEntry => 'Arbeitsbereich archivieren';
	@override String get restoreEntry => 'Arbeitsbereich wiederherstellen';
	@override String get archiveTitle => 'Arbeitsbereich archivieren';
	@override String get archiveDesc => 'Nach der Archivierung gilt für alle nur Lesen (Schreibzugriffe werden vom Server abgelehnt); jederzeit wiederherstellbar';
	@override String get archiveConfirm => 'Archivierung bestätigen';
	@override String get restoreTitle => 'Arbeitsbereich wiederherstellen';
	@override String get restoreDesc => 'Nach der Wiederherstellung ist der Arbeitsbereich wieder les- und schreibbar';
	@override String get restoreConfirm => 'Wiederherstellung bestätigen';
	@override String get archivedBanner => 'Arbeitsbereich archiviert: Inhalte sichtbar, Schreibzugriffe deaktiviert; der Owner kann auf der Mitgliedseite wiederherstellen';
	@override String get brandingTitle => 'Arbeitsbereich-Branding';
	@override String get brandingNameLabel => 'Brandname';
	@override String get brandingLogoLabel => 'Logo-URL';
	@override String get brandingLogoHint => 'https://… (URL des Arbeitsbereich-Logos)';
	@override String get brandingColorLabel => 'Hauptfarbe primaryColor';
	@override String get brandingColorHint => '#2474E5';
	@override String get brandingColorHelper => 'Nur #RRGGBB / #AARRGGBB; ungültige Werte fallen auf die Standard-Designfarbe zurück';
	@override String get brandingColorInvalid => 'Ungültiges Format der Hauptfarbe, nur #RRGGBB / #AARRGGBB';
	@override String get brandingSaved => 'Branding-Einstellungen gespeichert';
	@override String get brandingPreview => 'Vorschau der Hauptfarbe';
	@override String get brandingPreviewApplied => 'Die Hauptfarbe gilt im gesamten Arbeitsbereich';
	@override String get brandingPreviewFallback => 'Ohne Angabe oder bei ungültigem Wert gilt die Standard-Designfarbe';
	@override String get projectCreateEntry => 'Neues Projekt';
	@override String get projectCreateTitle => 'Neues Projekt';
	@override String get projectNameLabel => 'Projektname';
	@override String get projectNameHint => 'z. B. Website-Relaunch';
	@override String get projectNameRequired => 'Projektname darf nicht leer sein';
	@override String get projectDescLabel => 'Projektbeschreibung (optional)';
	@override String get projectDescHint => 'Was soll dieses Projekt liefern?';
	@override String get projectSubmit => 'Erstellen';
	@override String get projectCreateSuccess => 'Projekt erstellt';
	@override String get projectDetailTitle => 'Projektdetails';
	@override String get projectOwnerLabel => 'Verantwortlich';
	@override String get projectStatusLabel => 'Status';
	@override String get projectStatusActive => 'In Bearbeitung';
	@override String get projectStatusDone => 'Abgeschlossen';
	@override String get projectMarkDone => 'Als abgeschlossen markieren';
	@override String get projectReopen => 'Projekt erneut öffnen';
	@override String get projectStatusChanged => 'Projektstatus aktualisiert';
	@override String get projectTasksSection => 'Aufgaben';
	@override String get taskNewEntry => 'Neue Aufgabe';
	@override String get taskFormCreateTitle => 'Neue Aufgabe';
	@override String get taskFormEditTitle => 'Aufgabe bearbeiten';
	@override String get taskTitleLabel => 'Aufgabentitel';
	@override String get taskTitleRequired => 'Aufgabentitel darf nicht leer sein';
	@override String get taskAssigneeLabel => 'Verantwortlich (Arbeitsbereich-Mitglied)';
	@override String get taskAssigneeNone => 'Vorerst nicht zuweisen';
	@override String get taskAssigneeRefresh => 'Kandidaten aktualisieren';
	@override String get taskSubmitCreate => 'Aufgabe erstellen';
	@override String get taskSubmitSave => 'Speichern';
	@override String get taskCreatedToast => 'Aufgabe erstellt';
	@override String get taskExistingToast => 'Aufgabe mit gleichem Titel existiert bereits, vorhandene Aufgabe wird verwendet';
	@override String get taskUpdatedToast => 'Aufgabe gespeichert';
	@override String get taskFilterAll => 'Alle';
	@override String get taskStatusTodo => 'Offen';
	@override String get taskStatusDoing => 'In Bearbeitung';
	@override String get taskStatusReview => 'In Prüfung';
	@override String get taskStatusDone => 'Abgeschlossen';
	@override String taskAdvanceTo({required Object status}) => 'Weiter zu „${status}“';
	@override String taskFallbackMenuTitle({required Object title}) => '${title} zurücksetzen auf…';
	@override String taskStatusMovedToast({required Object status}) => 'Verschoben zu „${status}“';
	@override String get taskEmptyTitle => 'Noch keine Aufgaben';
	@override String get taskEmptySubtitle => 'Verfolgen Sie die Ausführung in vier Status: Offen → In Bearbeitung → In Prüfung → Abgeschlossen';
	@override String get projectsLoadMore => 'Mehr laden';
	@override String get projectW2SectionTitle => 'Projektzusammenarbeit';
	@override String get projectMembersEntry => 'Mitglieder';
	@override String get projectMilestonesEntry => 'Meilensteine';
	@override String get projectChannelsEntry => 'Projektkanäle';
	@override String get projectInsightsEntry => 'Inhaltsübersicht';
	@override String get projectNoPermission => 'Keine Berechtigung: Nur Projektmitglieder, die Projektleitung oder der Arbeitsbereich-Owner können dies ansehen';
	@override String get projectGuestReadonly => 'Als Gast (Guest) ist das Projekt nur lesbar';
	@override String get projectLoadMore => 'Mehr laden';
	@override String get projectMembersTitle => 'Projektmitglieder';
	@override String get projectMemberEmptyTitle => 'Noch keine Projektmitglieder';
	@override String get projectMemberEmptySubtitle => 'Die Projektleitung kann registrierte Nutzer in dieses Projekt einladen';
	@override String get projectMemberInviteTitle => 'Projektmitglieder einladen';
	@override String get projectMemberInviteFieldHint => 'ID des einzuladenden registrierten Nutzers';
	@override String get projectMemberInviteInvalidUid => 'Bitte eine gültige Nutzer-ID eingeben';
	@override String get projectMemberInviteSubmit => 'Einladen';
	@override String get projectMemberInviteSuccess => 'Zu den Projektmitgliedern hinzugefügt';
	@override String get projectMemberInviteExisting => 'Dieser Nutzer ist bereits Projektmitglied';
	@override String projectMemberRemoveConfirmTitle({required Object name}) => 'Projektmitglied ${name} entfernen';
	@override String get projectMemberRemoveConfirmDesc => 'Nach dem Entfernen verliert der Nutzer den Zugriff auf Projektinhalte (erneute Einladung möglich)';
	@override String get projectMemberRemoveSubmit => 'Entfernen';
	@override String get projectMemberRemovedToast => 'Entfernt';
	@override String get projectMemberAlreadyRemovedToast => 'Dieser Nutzer ist kein Projektmitglied mehr';
	@override String projectMemberTransferTitle({required Object name}) => 'Projektleitung an ${name} übertragen';
	@override String get projectMemberTransferDesc => 'Nach der Übertragung erhält die andere Person die vollständige Verwaltung dieses Projekts';
	@override String get projectMemberTransferConfirm => 'Übertragung bestätigen';
	@override String get projectMemberTransferDoneToast => 'Projektleitung übertragen';
	@override String get projectMilestonesTitle => 'Meilensteine';
	@override String get projectMilestoneEmptyTitle => 'Noch keine Meilensteine';
	@override String get projectMilestoneEmptySubtitle => 'Markieren Sie Schlüsselpunkte des Projekts mit Meilensteinen (Geplant → Erreicht, eine Richtung)';
	@override String get projectMilestoneCreateTitle => 'Neuer Meilenstein';
	@override String get projectMilestoneNameLabel => 'Name';
	@override String get projectMilestoneNameRequired => 'Meilensteinname darf nicht leer sein';
	@override String get projectMilestoneDueDateLabel => 'Fälligkeitsdatum (YYYY-MM-DD, optional)';
	@override String get projectMilestoneDueDateInvalid => 'Datumsformat sollte YYYY-MM-DD sein';
	@override String get projectMilestoneCreateSubmit => 'Erstellen';
	@override String get projectMilestoneCreatedToast => 'Meilenstein erstellt';
	@override String get projectMilestoneFilterAll => 'Alle';
	@override String get projectMilestoneFilterPlanned => 'Geplant';
	@override String get projectMilestoneFilterReached => 'Erreicht';
	@override String get projectMilestoneReach => 'Als erreicht markieren';
	@override String get projectMilestoneReachedToast => 'Meilenstein erreicht';
	@override String get projectMilestoneAlreadyReachedToast => 'Meilenstein bereits erreicht';
	@override String get projectMilestoneReachedHint => 'Erreicht (nicht zurücksetzbar)';
	@override String get projectMilestoneDueLabel => 'Fällig';
	@override String get projectChannelsTitle => 'Projektkanäle';
	@override String get projectChannelEmptyTitle => 'Noch keine verknüpften Kanäle';
	@override String get projectChannelEmptySubtitle => 'Nach der Verknüpfung eines Arbeitsbereich-Kanals werden dessen angepinnte Inhalte und neueste Beiträge in dieses Projekt gebündelt';
	@override String get projectChannelLinkTitle => 'Zu verknüpfenden Kanal auswählen';
	@override String get projectChannelNoCandidate => 'Keine Kanäle zum Verknüpfen verfügbar';
	@override String get projectChannelLinkedToast => 'Kanal verknüpft';
	@override String get projectChannelLinkExistingToast => 'Kanal bereits verknüpft';
	@override String projectChannelUnlinkTitle({required Object name}) => '„${name}“ entkoppeln';
	@override String get projectChannelUnlinkDesc => 'Nach dem Entkoppeln werden Inhalte dieses Kanals nicht mehr in das Projekt gebündelt';
	@override String get projectChannelUnlinkSubmit => 'Entkoppeln';
	@override String get projectChannelUnlinkedToast => 'Entkoppelt';
	@override String get projectInsightsTabPinned => 'Angepinnte Nachrichten';
	@override String get projectInsightsTabResources => 'Ressourcenlinks';
	@override String get projectInsightsTabActivity => 'Projektaktivität';
	@override String get projectInsightsTabPosts => 'Bezogene Beiträge';
	@override String get projectInsightsPinnedEmpty => 'Keine angepinnten Inhalte im verknüpften Kanal';
	@override String get projectInsightsResourcesEmpty => 'Noch keine Ressourcenlinks im Projekt';
	@override String get projectInsightsActivityEmpty => 'Noch keine Projektaktivität';
	@override String get projectInsightsPostsEmpty => 'Keine Beiträge im verknüpften Kanal';
	@override String projectInsightsPostAuthor({required Object name}) => 'Von ${name} veröffentlicht';
	@override String get advancedFeatures => 'Erweiterte Funktionen';
	@override String get assistantEntry => 'KI-Assistent';
	@override String get comingSoon => 'Demnächst';
	@override String get createOrJoinEnterprise => 'Organisation erstellen oder beitreten';
	@override String get featureComingSoon => 'Funktion in Entwicklung';
	@override String get filterDm => 'Direktnachrichten';
	@override String get filterEdit => 'Bearbeiten';
	@override String get filterEmptyTitle => 'Keine passenden Unterhaltungen';
	@override String get filterExternalChat => 'Externe Chats';
	@override String get filterFlagged => 'Markiert';
	@override String get filterInternalChat => 'Interne Chats';
	@override String get filterMentions => 'Erwähnungen';
	@override String get filterUnread => 'Ungelesen';
	@override String get filterUnreadEmptyTitle => 'Keine ungelesenen Unterhaltungen';
	@override String get myCard => 'Meine Karte';
	@override String get orgUnverified => 'Unverifiziert';
	@override String get recordFaceChat => 'Face-to-Face-Chat protokollieren';
	@override String get smartSummary => 'Intelligente Zusammenfassung';
	@override String get tabSchedule => 'Terminplan';
	@override String get tabTodo => 'Aufgaben';
	@override String get takeABreak => 'Kurze Pause machen';
	@override String get todoEmptyTitle => 'Keine Aufgaben';
}

// Path: account.alipaySim
class _Translations$account$alipaySim$de_DE extends Translations$account$alipaySim$zh_CN {
	_Translations$account$alipaySim$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get selectMethod => 'Zahlungsart wählen';
	@override String get confirmPay => 'Zahlung bestätigen';
	@override String get paymentAmount => 'Betrag:';
	@override String get balanceSource => 'Kontoguthaben';
	@override String get enterPassword => 'Bitte Zahlungs-Passwort eingeben';
	@override String get huabei => 'Huabei-Ratenzahlung';
	@override String get energy => 'Nach erfolgreicher Zahlung 5 g grüne Energie erhalten';
	@override String get alipaySuccess => 'Zahlung erfolgreich';
	@override String get storeName => 'IT-Flagship-Store';
}

// Path: organization.common
class _Translations$organization$common$de_DE extends Translations$organization$common$zh_CN {
	_Translations$organization$common$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get moreActions => 'Weitere Aktionen';
	@override String get rename => 'Umbenennen';
	@override String get close => 'Schließen';
	@override String get reload => 'Neu laden';
	@override String get createFailed => 'Erstellen fehlgeschlagen';
	@override String get addFailed => 'Hinzufügen fehlgeschlagen';
	@override String get confirmArchive => 'Archivieren bestätigen';
	@override String get forbidden403 => 'Keine Berechtigung für diese Aktion (403)';
	@override String get noMembers => 'Noch keine Mitglieder';
	@override String get targetUidHint => 'UID des anderen Nutzers (numerisch)';
	@override String get uidMustBePositive => 'Die Nutzer-UID muss eine positive Ganzzahl sein';
	@override String get loading => 'Wird geladen…';
	@override String get loadMore => 'Mehr laden';
	@override String get orgStatusPending => 'In Prüfung';
	@override String get orgStatusRejected => 'Prüfung nicht bestanden';
}

// Path: organization.home
class _Translations$organization$home$de_DE extends Translations$organization$home$zh_CN {
	_Translations$organization$home$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get createOrg => 'Organisation erstellen';
	@override String get orgNameLabel => 'Organisationsname (1-200 Zeichen)';
	@override String createFailedWith({required Object msg, required Object code}) => 'Erstellen fehlgeschlagen: ${msg} (${code})';
	@override String get createSubmittedPendingReview => 'Übermittelt. Wartet auf die Prüfung durch das Betreiberteam; das Unternehmen kann nach Genehmigung normal genutzt werden';
	@override String get tabOrg => 'Organisationen';
	@override String get myInvitations => 'Meine Einladungen';
	@override String get emptyHint => 'Du bist noch keiner Organisation beigetreten\nZum Aktualisieren nach unten ziehen oder oben rechts erstellen';
}

// Path: organization.detail
class _Translations$organization$detail$de_DE extends Translations$organization$detail$zh_CN {
	_Translations$organization$detail$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get leaveOrg => 'Organisation verlassen';
	@override String get leaveOrgBody => 'Der Austritt entzieht den Zugriff auf Verzeichnis, Gruppen, Kanäle und Dateien. Organisationsdateien bleiben erhalten. Für den Wiedereintritt ist eine Einladung erforderlich.';
	@override String get leaveFailed => 'Austritt fehlgeschlagen';
	@override String get leaveOwnerHint => 'Vor dem Austritt die Organisationsinhaberschaft übertragen';
	@override String get leaveCleanupFailed => 'Ausgetreten, aber lokale Einstellungen konnten nicht gelöscht werden. Neu starten und den gewählten Bereich prüfen';
	@override String get title => 'Organisationsdetails';
	@override String get notFound => 'Organisation nicht gefunden';
	@override String get archiveOrg => 'Organisation archivieren';
	@override String get archiveConfirmBody => 'Nach der Archivierung ist die Organisation schreibgeschützt; alle Schreiboperationen scheitern kontrolliert (fail-closed), nur Wiederherstellen (restore) entsperrt sie. Mitglieder und Daten werden nicht gelöscht.';
	@override String get restoreOrg => 'Organisation wiederherstellen';
	@override String get restoreConfirmBody => 'Nach der Wiederherstellung kehrt die Organisation in den active-Zustand zurück und Schreibzugriffe werden wieder geöffnet.';
	@override String get confirmRestore => 'Wiederherstellen bestätigen';
	@override String get restoreFailed => 'Wiederherstellen fehlgeschlagen';
	@override String get archiveFailed => 'Archivieren fehlgeschlagen';
	@override String get renameOrgTitle => 'Organisation umbenennen';
	@override String get renameOrgLabel => 'Organisationsname (1-200 Zeichen)';
	@override String get renameAction => 'Umbenennen';
	@override String get renameFailed => 'Umbenennen fehlgeschlagen';
	@override String get deletionPreflight => 'Löschvorprüfung des Kontos';
	@override String get deletionPreflightDesc => 'Anzeigen, welche Abhängigkeitsbereiche die Löschung dieses Kontos blockieren';
	@override String observedAt({required Object ts}) => 'Beobachtet am: ${ts}';
	@override String factDomains({required Object domains}) => 'Abgedeckte Abhängigkeitsbereiche: ${domains}';
	@override String get noBlockers => 'Keine Blocker';
	@override String get blockers => 'Blocker:';
	@override String get factUnavailable => 'Fakten der Abhängigkeitsbereiche nicht verfügbar, Löschvorprüfung abgelehnt (fail-closed)';
	@override String preflightFailed({required Object msg, required Object code}) => 'Vorprüfung fehlgeschlagen: ${msg} (${code})';
	@override String myRoleAndStatus({required Object role, required Object status}) => 'Meine Rolle: ${role} · Status: ${status}';
	@override String get archivedBadge => 'Organisation archiviert (schreibgeschützt)';
	@override String get archivedHint => 'Während der Archivierung werden alle Schreiboperationen abgelehnt; nur Wiederherstellen ist möglich';
	@override String defaultWsSet({required Object id}) => 'Standard-Workspace: ${id}';
	@override String get defaultWsUnset => 'Standard-Workspace: nicht festgelegt';
	@override String get defaultWsNote => 'Nur ein Verweis-Fakt; steht für keine Workspace-Mitgliedschaft';
	@override String get memberList => 'Mitglieder';
	@override String get memberListRestricted => 'Mitglieder (nur für owner/admin sichtbar)';
	@override String get invitationManage => 'Einladungsverwaltung';
	@override String get invitationManageRestricted => 'Einladungsverwaltung (nur owner/admin)';
	@override String get deptEntry => 'Abteilungsverzeichnis';
	@override String get deptEntryRestricted => 'Abteilungsverzeichnis (Verwaltung nur für Berechtigte)';
	@override String get more => 'Mehr';
	@override String get archiveEntrySubtitle => 'Wird schreibgeschützt; jederzeit wiederherstellbar';
	@override String get restoreEntrySubtitle => 'Zurück zu active';
}

// Path: organization.members
class _Translations$organization$members$de_DE extends Translations$organization$members$zh_CN {
	_Translations$organization$members$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mitglieder';
	@override String loadMoreFailed({required Object err}) => 'Nachladen fehlgeschlagen: ${err}';
	@override String get changeRole => 'Rolle ändern';
	@override String changeRoleBody({required Object name, required Object from, required Object to}) => 'Die Rolle von „${name}“ wird von ${from} zu ${to} geändert.';
	@override String get confirmChange => 'Änderung bestätigen';
	@override String get changeRoleFailed => 'Rollenänderung fehlgeschlagen';
	@override String get removeMember => 'Mitglied entfernen';
	@override String removeMemberBody({required Object name}) => '„${name}“ wird aus dieser Organisation entfernt. Das Konto wird nicht gelöscht.';
	@override String get confirmRemove => 'Entfernen bestätigen';
	@override String get removeFailed => 'Entfernen fehlgeschlagen';
	@override String get transferOwner => 'Eigentümerschaft übertragen';
	@override String transferOwnerBody({required Object name}) => 'Eine Organisation hat genau einen Owner (C04): Bestätige, „${name}“ zum Eigentümer zu machen.\nDu wirst zum normalen Admin/Mitglied herabgestuft. Dies beeinflusst direkt die Kontrolle über die Organisation.';
	@override String get confirmTransfer => 'Übertragung bestätigen';
	@override String get transferFailed => 'Übertragung fehlgeschlagen';
	@override String get demoteToMember => 'Zum Mitglied herabstufen';
	@override String get promoteToAdmin => 'Zum Admin befördern';
	@override String transferOwnerTo({required Object name}) => 'Eigentümerschaft an „${name}“ übertragen';
	@override String get ownerCannotChangeHere => 'Der Owner kann hier nicht geändert werden; verwende „Eigentümerschaft übertragen“';
	@override String get viewDetail => 'Profil anzeigen';
	@override String get suspendMember => 'Mitglied sperren';
	@override String suspendBody({required Object name}) => 'Zugriff von „${name}“ auf diese Organisation sperren (sofort wirksam; persönliches Konto und andere Organisationen bleiben unberührt). Jederzeit wiederherstellbar.';
	@override String get confirmSuspend => 'Sperren bestätigen';
	@override String get suspendFailed => 'Sperren fehlgeschlagen';
	@override String get restoreMember => 'Mitglied entsperren';
	@override String restoreBody({required Object name}) => 'Zugriff von „${name}“ auf diese Organisation wiederherstellen.';
	@override String get confirmRestoreMember => 'Entsperren bestätigen';
	@override String get restoreFailed => 'Entsperren fehlgeschlagen';
	@override String get offboardMember => 'Austritt (endgültig)';
	@override String offboardBody({required Object name}) => '${name} verlässt diese Organisation dauerhaft: removed ist ein endgültiger Zustand; ein Wiedereintritt erfordert eine neue Einladung.';
	@override String get confirmOffboard => 'Austritt bestätigen';
	@override String get offboardFailed => 'Austritt fehlgeschlagen';
	@override String get empty => 'Keine Mitglieder';
}

// Path: organization.invitations
class _Translations$organization$invitations$de_DE extends Translations$organization$invitations$zh_CN {
	_Translations$organization$invitations$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get inviteMember => 'Mitglied einladen';
	@override String get invitationCreated => 'Einladung erstellt';
	@override String get tokenOnceNotice => 'Der Empfangs-Token (token) wird nur einmal angezeigt; kopiere ihn jetzt und übermittle ihn außerhalb der App:';
	@override String get tokenCopied => 'Token kopiert';
	@override String get copyToken => 'Token kopieren';
	@override String inviteFailed({required Object msg, required Object code}) => 'Einladung fehlgeschlagen: ${msg} (${code})';
	@override String get acceptTitle => 'Einladung annehmen';
	@override String acceptBody({required Object orgId}) => 'Mit der Annahme trittest du der Organisation ${orgId} bei.\nDie Einladung ist einmalig; die Mitgliedschaft entscheidet der Server.';
	@override String get confirmAccept => 'Annehmen';
	@override String get acceptFailed => 'Annehmen fehlgeschlagen';
	@override String get rejectTitle => 'Einladung ablehnen';
	@override String get rejectBody => 'Nach der Ablehnung geht die Einladung in einen Endzustand und kann nicht mehr angenommen werden.';
	@override String get confirmReject => 'Ablehnung bestätigen';
	@override String get rejectFailed => 'Ablehnen fehlgeschlagen';
	@override String get revokeTitle => 'Einladung widerrufen';
	@override String get revokeBody => 'Nach dem Widerruf geht die Einladung in einen Endzustand; die Zielperson kann sie nicht mehr mit dem Token annehmen.';
	@override String get confirmRevoke => 'Widerruf bestätigen';
	@override String get revokeFailed => 'Widerrufen fehlgeschlagen';
	@override String get myInvitations => 'Meine Einladungen';
	@override String get manageInvitations => 'Einladungsverwaltung';
	@override String get createInvitation => 'Einladung erstellen';
	@override String get empty => 'Keine Einladungen';
	@override String get emptyRecord => 'Keine Einladungsdatensätze';
	@override String orgLine({required Object orgId}) => 'Organisation ${orgId}';
	@override String invitationLine({required Object invitationId}) => 'Einladung ${invitationId}';
	@override String targetLine({required Object targetUserId, required Object subtitle}) => 'Ziel ${targetUserId} · ${subtitle}';
	@override String get acceptNotice => 'Zum direkten Annehmen tippen – kein Token nötig;\nnach der Annahme ist die Mitgliedschaft serverseitig maßgeblich.';
	@override String get revokeAction => 'Widerrufen';
	@override String get acceptAction => 'Einladung annehmen';
	@override String get rejectAction => 'Ablehnen';
}

// Path: organization.departments
class _Translations$organization$departments$de_DE extends Translations$organization$departments$zh_CN {
	_Translations$organization$departments$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Abteilungsverwaltung';
	@override String statusLine({required Object status}) => 'Status: ${status}';
	@override String memberUidLine({required Object userId}) => 'Mitglied ${userId}';
	@override String get viewForbiddenDetail => 'Kein Zugriff auf diese Abteilung (nur aktive Mitglieder dieser Organisation)';
	@override String get viewForbidden => 'Kein Zugriff (nur aktive Mitglieder dieser Organisation)';
	@override String loadFailedWith({required Object msg, required Object code}) => 'Abteilung konnte nicht geladen werden: ${msg} (${code})';
	@override String loadFailed({required Object err}) => 'Abteilung konnte nicht geladen werden: ${err}';
	@override String get createSubHere => 'Hier eine Unterabteilung erstellen';
	@override String get movePickParent => 'Verschieben (neue übergeordnete Abteilung wählen)';
	@override String get addMemberByUid => 'Mitglied hinzufügen (per UID)';
	@override String get archiveDept => 'Abteilung archivieren';
	@override String get createRootDept => 'Root-Abteilung erstellen';
	@override String get deptNameLabel => 'Abteilungsname';
	@override String createUnder({required Object parent}) => 'Unter „${parent}“ erstellen';
	@override String get renameDept => 'Abteilung umbenennen';
	@override String get newNameLabel => 'Neuer Name';
	@override String get renameFailed => 'Umbenennen fehlgeschlagen';
	@override String get moveDept => 'Abteilung verschieben';
	@override String get rootLevel => 'Organisationswurzel';
	@override String get moveFailed => 'Verschieben fehlgeschlagen';
	@override String get addDeptMember => 'Abteilungsmitglied hinzufügen';
	@override String archiveConfirmBody({required Object name}) => 'Nach der Archivierung von „${name}“ ist die Abteilung schreibgeschützt (Mitgliedschaften bleiben erhalten).';
	@override String get archiveFailed => 'Archivieren fehlgeschlagen';
	@override String get emptyWithHint => 'Noch keine Abteilungen – erstelle oben rechts eine';
	@override String get empty => 'Keine Abteilungen';
	@override String get emptySubtitle => 'Mehrfachmitgliedschaft: Ein Mitglied kann mehreren Abteilungen angehören; Abteilungsmitglieder müssen zuerst Mitglieder dieser Organisation sein.';
	@override String get casConflictHint => 'Die Abteilung wurde gleichzeitig geändert; der neueste Baum wurde aktualisiert, bitte erneut versuchen.';
	@override String expandNode({required Object name}) => '"${name}" ausklappen';
	@override String collapseNode({required Object name}) => '"${name}" einklappen';
	@override String removeMemberUid({required Object userId}) => 'Mitglied ${userId} entfernen';
	@override String removeMemberConfirm({required Object userId, required Object name}) => 'Mitglied ${userId} wird aus "${name}" entfernt. Die Organisationsmitgliedschaft und Rollen in anderen Abteilungen bleiben unberührt (Mehrfachmitgliedschaft).';
	@override String get removeMemberFailed => 'Entfernen des Abteilungsmitglieds fehlgeschlagen';
	@override String get confirmRemoveMember => 'Entfernen bestätigen';
	@override String setDeptAdmin({required Object userId}) => '${userId} zum Abteilungsadmin ernennen';
	@override String unsetDeptAdmin({required Object userId}) => 'Abteilungsadmin-Rechte von ${userId} entziehen';
	@override String get setAdminFailed => 'Festlegen des Abteilungsadmins fehlgeschlagen';
	@override String get memberGovernActions => 'Mitgliedsverwaltungsaktionen';
}

// Path: organization.picker
class _Translations$organization$picker$de_DE extends Translations$organization$picker$zh_CN {
	_Translations$organization$picker$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Unternehmen wechseln';
	@override String get switchEnterprise => 'Unternehmen wechseln';
	@override String get switchFailed => 'Wechsel fehlgeschlagen';
	@override String get switchFailedRecovered => 'Wechsel fehlgeschlagen; vorherige Auswahl wiederhergestellt';
	@override String get noneSelected => 'Kein Unternehmen ausgewählt';
	@override String get emptyHint => 'Du bist noch keinem Unternehmen beigetreten.\nTippe unten auf „Unternehmen beitreten“ und gib den Einladungscode ein';
	@override String get joinEnterprise => 'Unternehmen beitreten';
	@override String get joinOrgIdLabel => 'Unternehmens-ID';
	@override String get joinOrgIdHint => 'Von einem Unternehmensadmin erhalten (numerische ID)';
	@override String get joinOrgIdInvalid => 'Gib eine gültige Unternehmens-ID ein (numerisch)';
	@override String get joinCodeLabel => 'Einladungscode des Unternehmens';
	@override String get joinSubmit => 'Beitreten';
	@override String get joinInvalidCode => 'Der Einladungscode des Unternehmens ist ungültig oder wurde widerrufen';
	@override String get joinExpiredCode => 'Der Einladungscode des Unternehmens ist abgelaufen';
	@override String joinFailed({required Object msg}) => 'Beitritt fehlgeschlagen: ${msg}';
	@override String get joinScanQr => 'Per QR-Code beitreten';
	@override String get joinCodeOnlyHint => '8-stelligen Einladungscode eingeben';
	@override String get joinConfirmTitle => 'Beitritt bestätigen';
	@override String joinConfirmWith({required Object name}) => 'Sie treten "${name}" bei';
	@override String joinConfirmWithRole({required Object role, required Object name}) => 'Als ${role} "${name}" beitreten?';
	@override String get joinRoleMember => 'Einfaches Mitglied';
	@override String get joinRoleAdmin => 'Admin';
	@override String get joinConfirmSubmit => 'Beitreten';
	@override String get joinBack => 'Zurück';
	@override String get joinQrHint => 'Auf den Unternehmens-Einladungs-QR-Code richten';
	@override String get joinQrInvalid => 'Kein gültiger Unternehmens-Einladungs-QR-Code';
}

// Path: organization.inviteColleagues
class _Translations$organization$inviteColleagues$de_DE extends Translations$organization$inviteColleagues$zh_CN {
	_Translations$organization$inviteColleagues$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kollegen einladen';
	@override String get tabInvite => 'Einladen';
	@override String get tabPossible => 'Mögliche Kollegen';
	@override String get wechatInvite => 'Per WeChat einladen';
	@override String get wechatInviteHint => 'Einladungscode an WeChat-Freunde senden; Beitritt über imboy';
	@override String get faceToFace => 'Persönlich einladen';
	@override String get faceToFaceHint => 'QR-Code scannen oder Einladungscode eingeben';
	@override String get fromWechatGroup => 'Aus WeChat-Gruppen hinzufügen';
	@override String get fromWechatGroupHint => 'Einladungscode in eine WeChat-Gruppe teilen';
	@override String shareText({required Object orgName, required Object code, required Object inviteUrl}) => '[${orgName}] lädt dich zu imboy ein\nEinladungscode: ${code} (7 Tage gültig)\nBeitreten über den Link: ${inviteUrl}\nimboy-App öffnen und den Code unter Kontakte > Organisation beitreten eingeben';
	@override String get shareToWechat => 'Einladung an WeChat teilen';
	@override String get copyInviteCode => 'Einladungscode kopieren';
	@override String get codeValidityHint => 'Der Einladungscode ist 7 Tage gültig; bei Neugenerierung verfällt der alte Code sofort';
	@override String get possibleLoadFailed => 'Mögliche Kollegen konnten nicht geladen werden, bitte erneut versuchen';
	@override String get revokeFailed => 'Widerruf fehlgeschlagen, bitte später erneut versuchen';
	@override String get guideCodeMissing => 'Noch kein aktiver Einladungscode; bitte zuerst einen Unternehmensadmin generieren lassen';
	@override String get possibleEmptyCta => 'Kollegen einladen';
	@override String get codeLoadFailed => 'Einladungscode konnte nicht geladen werden, bitte erneut versuchen';
	@override String get codeMissingHint => 'Noch kein aktiver Einladungscode; erst generieren, dann teilen';
	@override String get generateCode => 'Code generieren';
	@override String get generateForbidden => 'Nur Unternehmensadmins können den Einladungscode generieren';
	@override String get possibleEmpty => 'Keine ausstehenden Kollegen';
	@override String get possibleEmptyHint => 'Lade deine Kollegen ein';
	@override String invitedBy({required Object name}) => 'Von ${name} eingeladen';
	@override String invitedAt({required Object time}) => 'Eingeladen am ${time}';
	@override String get revoke => 'Widerrufen';
	@override String get revokeTitle => 'Einladung widerrufen';
	@override String revokeBody({required Object name}) => 'Einladung für "${name}" widerrufen?';
	@override String get revoked => 'Einladung widerrufen';
	@override String get groupStep1 => 'Einladungscode in deine WeChat-Gruppe teilen';
	@override String get groupStep2 => 'Kollegen kopieren den Code und öffnen die imboy-App';
	@override String get groupStep3 => 'Code unter Kontakte > Organisation beitreten eingeben';
	@override String codeLabelWith({required Object code}) => 'Einladungscode: ${code}';
}

// Path: organization.inviteQr
class _Translations$organization$inviteQr$de_DE extends Translations$organization$inviteQr$zh_CN {
	_Translations$organization$inviteQr$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get orgQrcode => 'Unternehmens-QR-Code';
	@override String get title => 'Mitglieder einladen';
	@override String get entryHint => 'QR-Code zeigen oder Code teilen – Beitritt per Scan oder Eingabe';
	@override String get scanHint => 'Andere scannen diesen Code mit dem imboy-Scanner, um dem Unternehmen beizutreten';
	@override String get codeLabel => 'Unternehmens-Einladungscode';
	@override String expiresWith({required Object date}) => 'Gültig bis ${date}';
	@override String get generate => 'Einladungscode generieren';
	@override String get generateFirst => 'Noch kein aktiver Einladungscode. Ein generierter Code ist 7 Tage gültig; Beitritt per Scan oder Eingabe.';
	@override String get regenerate => 'Neu generieren';
	@override String get regenerateTitle => 'Einladungscode neu generieren?';
	@override String get regenerateBody => 'Der aktuelle Code wird sofort ungültig; bereits geteilte QR-Codes und Codes funktionieren nicht mehr.';
	@override String get generateFailed => 'Generieren fehlgeschlagen, bitte später erneut versuchen';
	@override String get loadFailed => 'Einladungscode konnte nicht geladen werden';
	@override String get notAdmin => 'Nur der Owner/Admin des Unternehmens kann Einladungscodes verwalten';
	@override String get copyCode => 'Code kopieren';
	@override String get copied => 'Einladungscode kopiert';
	@override String get inviteDisabledPending => 'Das Unternehmen befindet sich in Prüfung; Mitglieder können erst nach Genehmigung eingeladen werden';
}

// Path: organization.directory
class _Translations$organization$directory$de_DE extends Translations$organization$directory$zh_CN {
	_Translations$organization$directory$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get currentMembersSection => 'Mitglieder dieser Ebene';
	@override String get structureSection => 'Organisationsstruktur';
	@override String get title => 'Verzeichnis';
	@override String get deptSection => 'Abteilungen';
	@override String get allMembersSection => 'Alle Mitglieder';
	@override String get membersRestricted => 'Die vollständige Mitgliederliste ist nur für Unternehmensadmins sichtbar; öffne eine Abteilung, um deren Mitglieder zu sehen.';
	@override String get imProfileEntry => 'IM-Profil anzeigen';
	@override String get myDepartmentsSection => 'Meine Abteilungen';
	@override String get membersSection => 'Mitglieder';
	@override String memberCountWith({required Object count}) => '${count} Mitglieder';
	@override String get searchHint => 'Abteilungen oder Mitglieder suchen';
	@override String get emptyDepartments => 'Keine Unterabteilungen';
	@override String get emptyMembers => 'Keine Mitglieder';
	@override String get emptySearch => 'Keine Treffer';
	@override String get switchVerifyFailed => 'Zielorganisation nicht verfügbar oder du bist kein Mitglied mehr';
	@override String get switchShellFailed => 'Workspaces der neuen Organisation konnten nicht geladen werden';
	@override String get inviteColleaguesRow => 'Kollegen einladen...';
	@override String memberTotal({required Object count}) => '${count} Mitglieder insgesamt';
}

// Path: organization.memberDetail
class _Translations$organization$memberDetail$de_DE extends Translations$organization$memberDetail$zh_CN {
	_Translations$organization$memberDetail$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get roleLabel => 'Unternehmensrolle';
	@override String get roleRestricted => 'Nur für Unternehmensadministratoren sichtbar';
	@override String get accountLabel => 'Anmeldekonto';
	@override String get joinedLabel => 'Beigetreten';
	@override String get workspacesTitle => 'Berechtigte Arbeitsbereiche';
	@override String get workspacesEmpty => 'Dieses Mitglied hat noch keinen Arbeitsbereich in diesem Unternehmen';
	@override String get workspacesFailed => 'Berechtigte Arbeitsbereiche konnten nicht geladen werden';
}

// Path: organization.manage
class _Translations$organization$manage$de_DE extends Translations$organization$manage$zh_CN {
	_Translations$organization$manage$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get renameWorkspace => 'Workspace umbenennen';
	@override String renameWorkspaceTitle({required Object name}) => '"${name}" umbenennen';
	@override String get wsMembersEntry => 'Mitglieder verwalten';
	@override String get renameGroup => 'Umbenennen';
	@override String renameGroupTitle({required Object name}) => '"${name}" umbenennen';
	@override String get groupGovernance => 'Mitglieder & Rollen';
	@override String get renameChannel => 'Umbenennen';
	@override String get channelAdmins => 'Administratoren';
	@override String get channelSubscribersEntry => 'Abonnenten';
	@override String get entry => 'Unternehmensverwaltung';
	@override String get entryRestricted => 'Unternehmensverwaltung (nur Admins)';
	@override String get title => 'Unternehmensverwaltung';
	@override String get orgNotFound => 'Unternehmen nicht gefunden oder nicht sichtbar';
	@override String roleLine({required Object role}) => 'Meine Rolle: ${role}';
	@override String get readOnlyHint => 'Unternehmensdaten nur lesbar; Verwaltungsaktionen nur für Inhaber/Admin';
	@override String get workspaceOwnerHint => 'Hier erscheinen nur Arbeitsbereiche, die dir gehören; Aktionen auf Unternehmensebene (Arbeitsbereich anlegen, Standard setzen) erfordern Inhaber oder Admin.';
	@override String get forbiddenTitle => 'Keine Verwaltungsberechtigung';
	@override String get forbiddenBody => 'Die Unternehmensverwaltung ist Inhaber und Admins vorbehalten. Bitte einen Admin, deine Rolle anzupassen.';
	@override String get workspaceSection => 'Arbeitsbereiche';
	@override String get createWorkspace => 'Arbeitsbereich anlegen';
	@override String get workspaceNameHint => 'Name des Arbeitsbereichs';
	@override String get workspaceEmpty => 'Noch keine Arbeitsbereiche';
	@override String get workspaceEmptyHint => 'Du bist in diesem Unternehmen noch keinem Arbeitsbereich beigetreten. Lege oben rechts einen an.';
	@override String get workspaceScopeNote => 'Hier erscheinen nur Arbeitsbereiche, denen du beigetreten bist; andere im Unternehmen nicht.';
	@override String get defaultBadge => 'Standard-Arbeitsbereich';
	@override String get notDefaultBadge => 'Nicht Standard';
	@override String get archivedBadge => 'Archiviert';
	@override String get ownerBadge => 'Ich bin Inhaber';
	@override String get memberBadge => 'Ich bin Mitglied';
	@override String get setDefault => 'Als Standard-Arbeitsbereich festlegen';
	@override String get archiveWorkspace => 'Arbeitsbereich archivieren';
	@override String archiveWorkspaceTitle({required Object name}) => '「${name}」 archivieren?';
	@override String get archiveWorkspaceBody => 'Ein archivierter Arbeitsbereich wird schreibgeschützt, seine Gruppen und Kanäle nehmen keine Schreibvorgänge mehr an. Ist er der Standard-Arbeitsbereich, lege zuerst einen Ersatz fest. Die Archivierung ist umkehrbar.';
	@override String get restoreWorkspace => 'Arbeitsbereich wiederherstellen';
	@override String get resourceSection => 'Gruppen und Kanäle';
	@override String get resourceNeedsWorkspace => 'Für Gruppen und Kanäle wird zuerst ein Arbeitsbereich benötigt.';
	@override String resourceLoadFailed({required Object err}) => 'Laden fehlgeschlagen: ${err}';
	@override String get retry => 'Erneut versuchen';
	@override String get groupSection => 'Unternehmensgruppen';
	@override String get createGroup => 'Gruppe anlegen';
	@override String get creationRecoveryUnavailable => 'Ergebnis unbekannt, bitte später erneut versuchen';
	@override String groupCreatedRenamePending({required Object gid}) => 'Gruppe erstellt (ID: ${gid}); Name nicht gespeichert';
	@override String get groupNameHint => 'Gruppenname';
	@override String get groupEmpty => 'Noch keine Unternehmensgruppen';
	@override String groupMembers({required Object count}) => '${count} Mitglieder';
	@override String get dissolveGroup => 'Gruppe auflösen';
	@override String dissolveGroupTitle({required Object name}) => '「${name}」 auflösen?';
	@override String get dissolveGroupBody => 'Das Auflösen ist nicht umkehrbar. Die Mitgliedschaft endet, Nachrichtenverlauf und Auditaufzeichnungen bleiben erhalten.';
	@override String get channelSection => 'Unternehmenskanäle';
	@override String get createChannel => 'Kanal anlegen';
	@override String get channelNameHint => 'Kanalname';
	@override String get channelPolicyNote => 'Unternehmenskanäle sind immer kostenlos und nicht öffentlich: kein öffentlicher Kanalverzeichniseintrag, Mitglieder abonnieren über den Arbeitsbereich.';
	@override String get channelEmpty => 'Noch keine Unternehmenskanäle';
	@override String channelSubscribers({required Object count}) => '${count} Abonnenten';
	@override String get createChannelFailed => 'Kanal konnte nicht angelegt werden';
	@override String get archiveChannel => 'Kanal archivieren';
	@override String archiveChannelTitle({required Object name}) => '「${name}」 archivieren?';
	@override String get archiveChannelBody => 'Ein archivierter Kanal verschwindet aus allen öffentlichen Ansichten und ist für Mitglieder nicht mehr sichtbar. Die Archivierung ist umkehrbar.';
	@override String get restoreChannel => 'Wiederherstellen';
	@override String get archivedChannelSection => 'Archivierte Kanäle';
}

// Path: organization.contactEntry
class _Translations$organization$contactEntry$de_DE extends Translations$organization$contactEntry$zh_CN {
	_Translations$organization$contactEntry$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get browserEntry => 'Verzeichnis öffnen';
	@override String get loadFailed => 'Organisationsdaten konnten nicht geladen werden';
}

// Path: organization.hub
class _Translations$organization$hub$de_DE extends Translations$organization$hub$zh_CN {
	_Translations$organization$hub$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get sectionResources => 'Organisationsressourcen';
	@override String get sectionAdmin => 'Adminbereich';
	@override String get zoneMembers => 'Mitglieder';
	@override String get zoneMembersDesc => 'Verzeichnis · nach Abteilungen stöbern';
	@override String get zoneDepartments => 'Abteilungen';
	@override String get zoneDepartmentsDesc => 'Abteilungsverzeichnis und Hierarchie';
	@override String get zoneGroups => 'Gruppen';
	@override String get zoneGroupsDesc => 'Organisationsgruppen · über die Verwaltung';
	@override String get zoneChannels => 'Kanäle';
	@override String get zoneChannelsDesc => 'Organisationskanäle · über die Verwaltung';
	@override String get zoneTools => 'Werkzeuge';
	@override String get zoneToolsDesc => 'Workspaces · Projekte und Zusammenarbeit';
	@override String get zoneOrgTools => 'Enterprise-Tools';
	@override String get zoneOrgToolsDesc => 'Autorisierte Workspace-Projekte und Aufgaben dieses Unternehmens';
	@override String get adminMembers => 'Mitgliederverwaltung';
	@override String get adminMembersDesc => 'Rollen · Mitglieder entfernen';
	@override String get adminInvitations => 'Einladungsverwaltung';
	@override String get adminInvitationsDesc => 'Einladungen erstellen und widerrufen';
	@override String get adminManage => 'Organisationsverwaltung';
	@override String get adminManageDesc => 'Workspaces · Gruppen · Kanäle';
}

// Path: organization.wsMembers
class _Translations$organization$wsMembers$de_DE extends Translations$organization$wsMembers$zh_CN {
	_Translations$organization$wsMembers$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String title({required Object ws}) => 'Workspace-Mitglieder · ${ws}';
	@override String get invite => 'Mitglieder einladen';
	@override String get inviteHint => 'Kontakte über den bestehenden Assistenten einladen (nur Workspace-Owner)';
	@override String get readOnlyHint => 'Schreibgeschützte Ansicht; Schreibaktionen nur für den Workspace-Owner.';
	@override String memberCount({required Object count}) => 'Mitglieder ${count}';
	@override String get notFound => 'Workspace nicht gefunden oder nicht sichtbar';
	@override String get roleOwner => 'Owner';
	@override String get roleMember => 'Mitglied';
	@override String get roleGuest => 'Gast';
	@override String get changeRole => 'Rolle ändern';
	@override String get setRoleMember => 'Als Mitglied festlegen';
	@override String get setRoleGuest => 'Als Gast festlegen';
	@override String get transferOwner => 'Owner übertragen';
	@override String transferOwnerTitle({required Object name}) => 'Owner von "${name}" übertragen?';
	@override String get transferOwnerBody => 'Danach bist du nicht mehr Workspace-Owner; die Governance-Rechte gehen an die neue Person über und können zurückübertragen werden.';
	@override String get removeMember => 'Mitglied entfernen';
	@override String removeTitle({required Object name}) => '"${name}" entfernen?';
	@override String get removeBody => 'Die Person verlässt den Workspace; bleibt sie Projekteigentümerin oder hat offene Aufgaben, lehnt der Server ab und listet die Konflikte.';
	@override String get archivedReadOnly => 'Workspace archiviert: Governance-Schreibaktionen sind serverseitig deaktiviert.';
}

// Path: organization.tools
class _Translations$organization$tools$de_DE extends Translations$organization$tools$zh_CN {
	_Translations$organization$tools$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Enterprise-Tools';
	@override String titleWithOrg({required Object name}) => '${name} · Enterprise-Tools';
	@override String get scopeNote => 'Es werden nur Workspaces dieses Unternehmens mit deiner Mitgliedschaft samt Projekte gelistet; Aufgaben und Meilensteine liegen in der Projektdetailseite.';
	@override String get archivedNote => 'Unternehmen archiviert: Der Tool-Bereich ist schreibgeschützt.';
	@override String get workspaceEmpty => 'Keine beigetretenen Workspaces';
	@override String get workspaceEmptyHint => 'Workspaces dieses Unternehmens ohne deine Mitgliedschaft erscheinen hier nicht.';
	@override String projectCount({required Object count}) => 'Projekte ${count}';
	@override String get projectsEmpty => 'Noch keine Projekte';
	@override String projectsError({required Object err}) => 'Projekte laden fehlgeschlagen: ${err}';
	@override String get moreInWorkspaceShell => 'Alle Workspaces durchsuchen';
	@override String get moreInWorkspaceShellHint => 'Globalen Workspace-Umschalter öffnen (unternehmensübergreifend).';
}

// Path: organization.chart
class _Translations$organization$chart$de_DE extends Translations$organization$chart$zh_CN {
	_Translations$organization$chart$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get zoomIn => 'Vergrößern';
	@override String get zoomOut => 'Verkleinern';
	@override String get fit => 'An Fenster anpassen';
	@override String get expand => 'Unterabteilungen ausklappen';
	@override String get collapse => 'Unterabteilungen einklappen';
	@override String get gestureHint => 'Ziehen zum Verschieben · Zusammen-/Auseinanderziehen zum Zoomen';
	@override String directMembers({required Object count}) => '${count} Mitglieder auf dieser Ebene';
}

// Path: organization.experienceUi
class _Translations$organization$experienceUi$de_DE extends Translations$organization$experienceUi$zh_CN {
	_Translations$organization$experienceUi$de_DE._(TranslationsDeDe root) : this._root = root, super.internal(root);

	final TranslationsDeDe _root; // ignore: unused_field

	// Translations
	@override String get switchSpace => 'Space wechseln';
	@override String get personalSpace => 'Persönlicher Space';
	@override String get enterpriseSpaces => 'Unternehmens-Spaces';
	@override String get currentSpace => 'Aktueller Space';
	@override String get enterpriseInfo => 'Unternehmensinfo';
	@override String get collaborationSpace => 'Kollaborations-Spaces';
	@override String get groupContent => 'Gruppeninhalte';
	@override String get groupCollaboration => 'Gruppenzusammenarbeit';
	@override String get defaultWorkspace => 'Standard-Arbeitsbereich';
	@override String get defaultAvailable => 'Eingerichtet';
	@override String get defaultUnknown => 'Vorübergehend nicht verfügbar';
	@override String get defaultHint => 'Tritt dem entsprechenden Arbeitsbereich bei, um darauf zuzugreifen. Die Standardeinstellung gewährt keinen automatischen Zugriff.';
	@override String get accountCheck => 'Prüfungen vor der Kontolöschung';
	@override String workspaceContext({required Object name}) => 'Arbeitsbereich: ${name}';
	@override String get noIntro => 'Keine Beschreibung';
}

/// The flat map containing all translations for locale <de-DE>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsDeDe {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'account.account' => 'Konto',
			'account.accountSecurity' => 'Kontosicherheit',
			'account.avatar' => 'Profilbild',
			'account.accountSecurityEnhance' => 'Kontosicherheit verbessern',
			'account.bindMobile' => 'Mobilfunknummer verbinden',
			'account.bindMobileFor' => 'Für Anmeldung, Passwort-Wiederherstellung und Empfang wichtiger Benachrichtigungen',
			'account.linkEmail' => 'E-Mail verknüpfen',
			'account.linkEmailFor' => 'Für Anmeldung, Identitätsprüfung und Erhalt von Rechnungen',
			'account.codeSentToEmail' => 'Bestätigungscode an E-Mail gesendet',
			'account.codeSentToMobile' => 'Bestätigungscode an Mobilfunknummer gesendet',
			'account.currentDevice' => 'Aktuelles Gerät',
			'account.deviceAvailableSpace' => 'Verfügbarer Speicherplatz auf dem Gerät',
			'account.deviceList' => 'Geräteliste',
			'account.deviceName' => 'Gerätename',
			'account.deviceType' => 'Gerätetyp',
			'account.deviceUsedSpace' => 'Vom Gerät verwendeter Speicherplatz',
			'account.email' => 'E-Mail',
			'account.forgotPassword' => 'Passwort vergessen?',
			'account.gender' => 'Geschlecht',
			'account.groupQrcode' => 'Gruppen-QR-Code',
			'account.hintLoginAccount' => 'Konto/E-Mail',
			'account.logOut' => 'Abmelden',
			'account.areYouSureLogOut' => 'Möchten Sie sich wirklich abmelden?',
			'account.login' => 'Anmelden',
			'account.loginDeviceManagement' => 'Geräteverwaltung',
			'account.loginEmail' => 'Anmelde-E-Mail',
			'account.logoutAccount' => 'Konto löschen',
			'account.mobile' => 'Mobilfunk',
			'account.mobileQuickLogin' => 'Schnellanmeldung',
			'account.myAccount' => 'Mein Konto',
			'account.myQrcode' => 'Mein QR-Code',
			'account.newPassword' => 'Neues Passwort',
			'account.newlyRegisteredPeople' => 'Kürzlich registrierte Personen',
			'account.nickname' => 'Spitzname',
			'account.nicknameHint' => 'Spitzname eingeben',
			'account.password' => 'Passwort',
			'account.recoverPassword' => 'Passwort wiederherstellen',
			'account.birthday' => 'Geburtstag',
			'account.region' => 'Region',
			'account.retypePassword' => 'Passwort erneut eingeben',
			'account.scanQrCode' => 'QR-Code scannen',
			'account.setNickname' => 'Spitzname festlegen',
			'account.signature' => 'Signatur',
			'account.signup' => 'Registrieren',
			'account.sourceQrcode' => 'Durch Scannen hinzufügen',
			'account.changeEmail' => 'E-Mail ändern',
			'account.bindEmail' => 'E-Mail binden',
			'account.currentEmail' => 'Aktuelle E-Mail',
			'account.setPassword' => 'Passwort festlegen',
			'account.setLoginPassword' => 'Anmeldepasswort festlegen',
			'account.enhanceAccountSecurity' => 'Kontosicherheit verbessern',
			'account.passwordLengthRequirement' => 'Passwortlänge: 4-32 beliebige Zeichen',
			'account.passwordMinLength' => ({required Object min}) => 'Passwort muss mindestens ${min} Zeichen lang sein',
			'account.pleaseEnterPassword' => 'Bitte Passwort eingeben',
			'account.changeMobile' => 'Mobilfunknummer ändern',
			'account.currentMobile' => 'Aktuelle Mobilfunknummer',
			'account.newMobile' => 'Neue Mobilfunknummer',
			'account.enterMobileHint' => 'Mobilfunknummer eingeben',
			'account.privacyLogoutAccount' => 'Konto löschen',
			'account.wallet' => 'Wallet',
			'account.changeLoginPassword' => 'Anmeldepasswort ändern',
			'account.otherDevice' => 'Anderes Gerät',
			'account.loginPassword' => 'Anmeldepasswort',
			'account.loginPasswordDesc' => 'Wird für die Anmeldung im IMBoy-Konto verwendet',
			'account.oldPassword' => 'Altes Passwort',
			'account.enterOldPassword' => 'Bitte altes Passwort eingeben',
			'account.enterNewPassword' => 'Bitte neues Passwort eingeben',
			'account.enterNewPasswordAgain' => 'Bitte neues Passwort erneut eingeben',
			'account.myQRCode' => 'Mein QR-Code',
			'account.profile' => 'Profil',
			'account.setGender' => 'Geschlecht festlegen',
			'account.setBirthday' => 'Geburtstag festlegen',
			'account.nicknameRules' => '• Spitznamenlänge: 2-24 Zeichen • Darf nicht nur aus Leerzeichen oder Emojis bestehen • Darf keine sensiblen Wörter enthalten • Änderungen werden in allen Chats angezeigt',
			'account.refreshDeviceKey' => 'Geräteschlüssel aktualisieren',
			'account.refreshDeviceKeyHint' => 'Wenn Nachrichten nicht entschlüsselt werden können, Schlüssel hier aktualisieren',
			'account.refreshingDeviceKey' => 'Geräteschlüssel wird aktualisiert...',
			'account.deviceKeyRefreshed' => 'Geräteschlüssel aktualisiert',
			'account.rechargeTitle' => 'Aufladen',
			'account.rechargeAmountHint' => 'Betrag eingeben (Yuan), 0.01–10000',
			'account.rechargeAmountExample' => 'z. B. 100',
			'account.e2eeDeviceIdLabel' => 'Geräte-ID',
			'account.webQRLoginTitle' => 'Per QR-Code anmelden',
			'account.webQRLoginHint' => 'QR-Code mit der ImBoy-App scannen',
			'account.webSwitchToPassword' => 'Mit Passwort anmelden',
			'account.webPasswordLoginTitle' => 'Konto-Anmeldung',
			'account.webAccountHint' => 'Konto/Handy/E-Mail eingeben',
			'account.webPasswordHint' => 'Passwort eingeben',
			'account.pleaseRelogin' => 'Bitte neu anmelden',
			'account.otherLoginMethods' => 'Weitere Anmeldemethoden',
			'account.payMethodTitle' => 'Zahlungsart wählen',
			'account.payMethodAlipay' => 'Alipay',
			'account.payMethodWechat' => 'WeChat Pay',
			'account.payMethodWallet' => 'Wallet-Guthaben',
			'account.payMethodMock' => 'Testzahlung (nur Entwicklung)',
			'account.payMethodComingSoon' => 'Diese Zahlungsart ist bald verfügbar',
			'account.payCancelled' => 'Zahlung abgebrochen',
			'account.alipaySim.selectMethod' => 'Zahlungsart wählen',
			'account.alipaySim.confirmPay' => 'Zahlung bestätigen',
			'account.alipaySim.paymentAmount' => 'Betrag:',
			'account.alipaySim.balanceSource' => 'Kontoguthaben',
			'account.alipaySim.enterPassword' => 'Bitte Zahlungs-Passwort eingeben',
			'account.alipaySim.huabei' => 'Huabei-Ratenzahlung',
			'account.alipaySim.energy' => 'Nach erfolgreicher Zahlung 5 g grüne Energie erhalten',
			'account.alipaySim.alipaySuccess' => 'Zahlung erfolgreich',
			'account.alipaySim.storeName' => 'IT-Flagship-Store',
			'account.logoutPendingHeader' => 'Status des Löschantrags',
			'account.logoutPendingBanner' => ({required Object date}) => 'Löschantrag eingereicht, Abschluss voraussichtlich am ${date}',
			'account.logoutCancelRequest' => 'Löschantrag zurückziehen',
			'account.logoutCancelledNote' => 'Löschantrag zurückgezogen',
			'account.logoutRetainedHeader' => 'Hinweis zur Datenaufbewahrung',
			'account.logoutRetainedNote' => 'Nach Abschluss der Löschung werden Audit-Protokolle und Finanzunterlagen gesetzlich vorgeschrieben aufbewahrt und anonymisiert; von Ihnen geführte Gruppen/Arbeitsbereiche/Kanäle werden vorrangig an Nachfolgemitglieder übertragen',
			'account.bindAlipay' => 'Alipay verknüpfen',
			'account.unbindAlipay' => 'Verknüpfung aufheben',
			'account.confirmUnbindAlipay' => 'Verknüpfung aufheben bestätigen',
			'agent.plazaTitle' => 'KI-Assistenten',
			'agent.transparencyBanner' => 'Alle Mitglieder hier sind KI-Assistenten und klar als solche gekennzeichnet. In verschlüsselten Chats gibt es nur echte Menschen.',
			'agent.searchHint' => 'Assistenten suchen',
			'agent.emptyTitle' => 'Noch keine KI-Assistenten. Schau später wieder vorbei.',
			'agent.searchEmpty' => 'Keine passenden Assistenten',
			'agent.sendMessage' => 'Nachricht',
			'agent.badgeAi' => 'KI',
			'agent.badgeOfficial' => 'Offiziell',
			'agent.badgeAiA11y' => 'KI-Assistent',
			'agent.badgeOfficialA11y' => 'Offizielles Konto',
			'agent.legacyBotGoPlaza' => 'Zu den KI-Assistenten',
			'agent.legacyBotMigrated' => 'Dieser Bot-Zugang wurde aktualisiert. Bitte chatten Sie mit den Assistenten im Bereich KI-Assistenten',
			'agentTask.title' => 'KI-Aufgabe',
			'agentTask.working' => 'Wird ausgeführt',
			'agentTask.submitted' => 'Eingereicht',
			'agentTask.progress' => 'In Bearbeitung',
			'agentTask.completed' => 'Abgeschlossen',
			'agentTask.failed' => 'Fehlgeschlagen',
			'agentTask.cancelled' => 'Abgebrochen',
			'agentTask.awaitingApproval' => 'Genehmigung ausstehend',
			'agentTask.approve' => 'Genehmigen',
			'agentTask.reject' => 'Ablehnen',
			'appeal.title' => 'Maßnahmen & Einspruch',
			'appeal.actionsSection' => 'Maßnahmen gegen mich',
			'appeal.actionsEmpty' => 'Keine Maßnahmen',
			'appeal.appealsSection' => 'Meine Einsprüche',
			'appeal.appealsEmpty' => 'Keine Einsprüche',
			'appeal.dialogTitle' => 'Einspruch einlegen',
			'appeal.reasonPlaceholder' => 'Begründung angeben (erforderlich)',
			'appeal.submit' => 'Einspruch senden',
			'appeal.submitFailed' => 'Senden fehlgeschlagen',
			'appeal.appealedTag' => 'Eingesprochen',
			'appeal.appealableTag' => 'Einspruch möglich',
			'appeal.actionWarning' => 'Warnung',
			'appeal.actionGroupMute' => 'Gruppen-Stummschaltung',
			'appeal.actionGroupKick' => 'Aus Gruppe entfernt',
			'appeal.actionReject' => 'Inhalt abgelehnt',
			'appeal.actionAccountRestrict' => 'Konto eingeschränkt',
			'appeal.actionContentRemoval' => 'Inhalt entfernt',
			'appeal.statusPending' => 'In Prüfung',
			'appeal.statusAccepted' => 'Aufgehoben',
			'appeal.statusRejected' => 'Aufrechterhalten',
			'appeal.allClearTitle' => 'Alles in Ordnung',
			'appeal.allClearSubtitle' => 'Keine Maßnahmen gegen dich, kein Einspruch erforderlich.',
			'billing.title' => 'Abo-Pläne',
			'billing.planPeriodMonthly' => 'Monatlich',
			'billing.planPeriodYearly' => 'Jährlich',
			'billing.subscribe' => 'Jetzt abonnieren',
			'billing.currentPlan' => 'Aktueller Plan',
			'billing.noPlans' => 'Noch keine Pläne verfügbar. Bleiben Sie gespannt',
			'billing.loadFailed' => 'Laden fehlgeschlagen. Zum Wiederholen nach unten ziehen',
			'billing.retry' => 'Wiederholen',
			'billing.paySuccess' => 'Abo erfolgreich abgeschlossen',
			'billing.payFailed' => 'Zahlung fehlgeschlagen',
			'billing.payCancelled' => 'Zahlung abgebrochen',
			'billing.payMethodTitle' => 'Zahlungsart wählen',
			'billing.payMethodMock' => 'Testzahlung (nur Entwicklung)',
			'billing.payMethodAlipay' => 'Alipay',
			'billing.payMethodWechat' => 'WeChat Pay',
			'billing.payMethodComingSoon' => 'Diese Zahlungsart ist bald verfügbar',
			'billing.quotaUnlimited' => 'Unbegrenzt',
			'channel.composeLeaveImagesLost' => 'Ausgewählte Bilder werden nicht gespeichert. Trotzdem verlassen?',
			'channel.title' => 'Kanäle',
			'channel.loading' => 'Laden...',
			'channel.subscribed' => 'Abonniert',
			'channel.managed' => 'Verwaltet',
			'channel.writeArticle' => 'Beitrag schreiben',
			'channel.discover' => 'Entdecken',
			'channel.create' => 'Kanal erstellen',
			'channel.creationRecoveryUnavailable' => 'Erstellungsergebnis unbekannt, bitte später erneut versuchen',
			'channel.searchHint' => 'Kanalname oder ID suchen',
			'channel.noResults' => 'Keine Kanäle gefunden',
			'channel.noRecommendedChannels' => 'Keine empfohlenen Kanäle Schauen Sie später vorbei',
			'channel.noSubscribedChannels' => 'Keine abonnierten Kanäle Entdecke mehr Kanäle',
			'channel.noManagedChannels' => 'Keine verwalteten Kanäle Erstelle einen Kanal um zu beginnen',
			'channel.subscribers' => 'Abonnenten',
			'channel.subscribe' => 'Abonnieren',
			'channel.subscribeSuccess' => 'Erfolgreich abonniert',
			'channel.subscribeFailed' => 'Abonnieren fehlgeschlagen',
			'channel.unsubscribe' => 'Abo beenden',
			'channel.unsubscribeConfirm' => 'Abo beenden',
			'channel.unsubscribeConfirmDesc' => 'Möchten Sie dieses Abo wirklich beenden? Sie erhalten keine Nachrichten mehr.',
			'channel.share' => 'Teilen',
			'channel.shareNotImplemented' => 'Teilen-Funktion kommt bald',
			'channel.nameLabel' => 'Kanalname',
			'channel.nameHint' => 'Kanalnamen eingeben',
			'channel.nameRequired' => 'Kanalname ist erforderlich',
			'channel.nameTooLong' => 'Kanalname darf 50 Zeichen nicht überschreiten',
			'channel.descriptionLabel' => 'Beschreibung',
			'channel.descriptionHint' => 'Beschreiben Sie Ihren Kanal (optional)',
			'channel.customIdLabel' => 'Benutzerdefinierte ID (optional)',
			'channel.customIdHint' => 'z.B.: mein_kanal',
			'channel.customIdHelper' => 'Ermöglicht Suche nach Kanal-ID',
			'channel.customIdInvalid' => 'Nur Buchstaben, Zahlen und Unterstriche erlaubt',
			'channel.customIdLength' => 'Muss 4-30 Zeichen lang sein',
			'channel.typePublic' => 'Öffentlich',
			'channel.typePrivate' => 'Privat',
			'channel.typePublicDesc' => 'Jeder kann Ihren Kanal finden und abonnieren',
			'channel.typePrivateDesc' => 'Nur über Einladungslink zugänglich',
			'channel.createTips' => 'Nach Erstellung können Sie Nachrichten an alle Abonnenten senden. Nur Admins können Kanalnachrichten senden.',
			'channel.today' => 'Heute',
			'channel.yesterday' => 'Gestern',
			'channel.daysAgo' => 'Tage her',
			'channel.messages' => 'Nachrichten',
			'channel.views' => 'Aufrufe',
			'channel.editChannel' => 'Kanal bearbeiten',
			'channel.editChannelNotImplemented' => 'Kanal bearbeiten kommt bald',
			'channel.manageAdmins' => 'Admins verwalten',
			'channel.manageAdminsNotImplemented' => 'Admins verwalten kommt bald',
			'channel.manageSubscribers' => 'Abonnenten verwalten',
			'channel.manageSubscribersNotImplemented' => 'Abonnenten verwalten kommt bald',
			'channel.deleteChannel' => 'Kanal löschen',
			'channel.deleteChannelConfirm' => 'Sind Sie sicher, dass Sie diesen Kanal löschen möchten? Dies kann nicht rückgängig gemacht werden.',
			'channel.deleteChannelNotImplemented' => 'Kanal löschen kommt bald',
			'channel.channelDeleted' => 'Kanal gelöscht',
			'channel.deleteChannelFailed' => 'Kanal löschen fehlgeschlagen',
			'channel.writeMessage' => 'Nachricht schreiben...',
			'channel.publishFailed' => 'Veröffentlichung fehlgeschlagen',
			'channel.pinMessage' => 'Nachricht anpinnen',
			'channel.unpinMessage' => 'Anpinnen aufheben',
			'channel.pinMessageNotImplemented' => 'Anpinnen kommt bald',
			'channel.unpinMessageNotImplemented' => 'Anpinnen aufheben kommt bald',
			'channel.messagePinned' => 'Nachricht angepinnt',
			'channel.messageUnpinned' => 'Anpinnen aufgehoben',
			'channel.deleteMessage' => 'Nachricht löschen',
			'channel.deleteMessageConfirm' => 'Sind Sie sicher, dass Sie diese Nachricht löschen möchten?',
			'channel.messageDeleted' => 'Nachricht gelöscht',
			'channel.addAdmin' => 'Admin hinzufügen',
			'channel.addAdminSuccess' => 'Admin erfolgreich hinzugefügt',
			'channel.addAdminFailed' => 'Admin hinzufügen fehlgeschlagen',
			'channel.removeAdmin' => 'Admin entfernen',
			'channel.removeAdminConfirm' => 'Sind Sie sicher, dass Sie diesen Admin entfernen möchten?',
			'channel.removeAdminSuccess' => 'Admin entfernt',
			'channel.removeAdminFailed' => 'Admin entfernen fehlgeschlagen',
			'channel.changeRole' => 'Rolle ändern',
			'channel.updateRoleSuccess' => 'Rolle erfolgreich aktualisiert',
			'channel.updateRoleFailed' => 'Rolle aktualisieren fehlgeschlagen',
			'channel.selectFromContacts' => 'Aus Kontakten wählen',
			'channel.searchContactsHint' => 'Spitzname oder Konto suchen',
			'channel.noContactsToAdd' => 'Alle Freunde sind bereits Administratoren',
			'channel.selectRole' => 'Rolle wählen',
			'channel.noAdmins' => 'Keine Admins vorhanden',
			'channel.roleCreator' => 'Ersteller',
			'channel.roleAdmin' => 'Admin',
			'channel.roleAdminDesc' => 'Kanal verwalten',
			'channel.roleEditor' => 'Editor',
			'channel.roleEditorDesc' => 'Nachrichten veröffentlichen',
			'channel.searchSubscribers' => 'Abonnenten suchen',
			'channel.subscriberSearchHint' => 'Nach Name oder ID suchen',
			'channel.noSearchResults' => 'Keine passenden Abonnenten gefunden',
			'channel.noSubscribers' => 'Keine Abonnenten vorhanden',
			'channel.removeSubscriber' => 'Abonnent entfernen',
			'channel.removeSubscriberConfirm' => 'Sind Sie sicher, dass Sie diesen Abonnenten entfernen möchten?',
			'channel.removeSubscriberSuccess' => 'Abonnent entfernt',
			'channel.removeSubscriberFailed' => 'Abonnent entfernen fehlgeschlagen',
			'channel.subscribedAt' => 'Abonniert am',
			'channel.viewProfile' => 'Profil ansehen',
			'channel.inviteFromContacts' => 'Freunde einladen',
			'channel.inviteSearchHint' => 'Spitzname oder Konto suchen',
			'channel.noContactsToInvite' => 'Alle Freunde bereits eingeladen oder abonniert',
			'channel.inviteSuccess' => 'Einladung gesendet',
			'channel.inviteFailed' => 'Einladung fehlgeschlagen',
			'channel.updateSuccess' => 'Kanal erfolgreich aktualisiert',
			'channel.updateFailed' => 'Kanal aktualisieren fehlgeschlagen',
			'channel.typeCannotChange' => 'Kann nach Erstellung nicht geändert werden',
			'channel.stats' => 'Statistiken',
			'channel.shareToChat' => 'An Freund senden',
			'channel.qrcode' => 'Kanal-QR-Code',
			'channel.qrcodeTips' => ({required Object days, required Object date}) => 'QR-Code ${days} Tage gültig (bis ${date})',
			'channel.defaultName' => 'Unbenannter Kanal',
			'channel.noMessagesManaged' => 'Der Kanal hat noch keine Inhalte veröffentlicht',
			'channel.noMessagesManagedDesc' => 'Als Kanalinhaber können Sie unten den ersten Inhalt veröffentlichen',
			'channel.noMessagesVisitor' => 'Abonnieren, um die Inhalte des Kanals zu sehen',
			'channel.noMessagesVisitorDesc' => 'Die Inhalte dieses Kanals werden nach dem Abonnieren angezeigt',
			'channel.noMessagesSubscribed' => 'Der Kanal hat noch keine Inhalte veröffentlicht',
			'channel.noMessagesSubscribedDesc' => 'Erfolgreich abonniert! Bitte warte auf neue Beiträge des Autors',
			'channel.continueEditing' => 'Weiter bearbeiten',
			'channel.publishFirstContent' => 'Ersten Inhalt veröffentlichen',
			'channel.noSubscribersDesc' => 'Noch keine Abonnenten. Teilen Sie den Kanal mit Ihren Freunden',
			'channel.emoji' => 'Emoji',
			'channel.justNow' => 'Gerade eben',
			'channel.minutesAgo' => 'Min.',
			'channel.hoursAgo' => 'Std.',
			'channel.weeksAgo' => 'Wo.',
			'channel.visibilityLabel' => 'Sichtbarkeit',
			'channel.accessTypeLabel' => 'Preismodell',
			'channel.accessTypeFree' => 'Kostenlos',
			'channel.accessTypePaid' => 'Kostenpflichtig',
			'channel.typePublicPaidDesc' => 'Jeder kann den Kanal entdecken und nach dem Kauf abonnieren',
			'channel.typePrivatePaidDesc' => 'Nur eingeladene Nutzer können den Kaufvorgang starten und nach Zahlung abonnieren',
			'channel.addImage' => 'Bild hinzufügen',
			'channel.allCategories' => 'Alle',
			'channel.articleBodyHint' => 'Schreiben Sie etwas… Fett, Kursiv, Überschriften, Listen u. a. Formatierungen werden unterstützt',
			'channel.cancelOrder' => 'Bestellung stornieren',
			'channel.cancelOrderConfirmMessage' => 'Diese offene Bestellung wirklich stornieren? Nach dem Stornieren ist keine Zahlung mehr möglich.',
			'channel.cancelOrderConfirmTitle' => 'Stornierung bestätigen',
			'channel.cancelOrderSuccess' => 'Bestellung storniert',
			'channel.channelNotFound' => 'Kanal nicht gefunden',
			'channel.comment' => 'Kommentar',
			'channel.commentDeleteNoPermission' => 'Keine Berechtigung zum Löschen dieses Kommentars',
			'channel.commentFailed' => 'Kommentar fehlgeschlagen',
			'channel.coverLabel' => 'Cover',
			'channel.coverSet' => 'Als Cover festgelegt',
			'channel.deleteComment' => 'Kommentar löschen',
			'channel.deleteCommentConfirm' => 'Diesen Kommentar wirklich löschen?',
			'channel.formatBold' => 'Fett',
			'channel.formatHeading' => 'Überschrift',
			'channel.formatItalic' => 'Kursiv',
			'channel.formatLink' => 'Link',
			'channel.formatList' => 'Liste',
			'channel.formatQuote' => 'Zitat',
			'channel.formatStrikethrough' => 'Durchgestrichen',
			'channel.like' => 'Gefällt mir',
			'channel.linkTextPlaceholder' => 'Linktext',
			'channel.myOrders' => 'Meine Bestellungen',
			'channel.noComments' => 'Keine Kommentare',
			'channel.noOrders' => 'Keine Bestellungen',
			'channel.orderAmount' => 'Betrag',
			'channel.orderChannel' => 'Kanal',
			'channel.orderContinuePay' => 'Weiter bezahlen',
			'channel.orderCreatedAt' => 'Bestelldatum',
			'channel.orderDetail' => 'Bestelldetails',
			'channel.orderNo' => 'Bestellnr.',
			'channel.orderPaidAt' => 'Zahlungsdatum',
			'channel.orderPaymentMethod' => 'Zahlungsart',
			'channel.orderStatusCancelled' => 'Storniert',
			'channel.orderStatusExpired' => 'Abgelaufen',
			'channel.orderStatusLabel' => 'Status',
			'channel.orderStatusPaid' => 'Bezahlt',
			'channel.orderStatusPending' => 'Offen',
			'channel.orderStatusRefunded' => 'Erstattet',
			'channel.orderStatusRefunding' => 'Erstattung läuft',
			'channel.orderSubscriptionPeriod' => 'Abo-Zeitraum',
			'channel.orderValidUntil' => 'Gültig bis',
			'channel.payAlipay' => 'Alipay',
			'channel.payWallet' => 'Wallet-Guthaben',
			'channel.payWechat' => 'WeChat Pay',
			'channel.preview' => 'Vorschau',
			'channel.publish' => 'Veröffentlichen',
			'channel.readFull' => 'Weiterlesen',
			'channel.refundApply' => 'Erstattung beantragen',
			'channel.refundConfirmMessage' => 'Für diese Bestellung wirklich eine Erstattung beantragen? Nach der Erstattung wird das Abo beendet.',
			'channel.refundConfirmTitle' => 'Erstattung bestätigen',
			'channel.refundSuccess' => 'Erstattungsantrag eingereicht',
			'channel.reply' => 'Antworten',
			'channel.replyTo' => 'Antwort an',
			'channel.sortNewest' => 'Neueste',
			'channel.sortPopular' => 'Beliebt',
			'channel.titleOptional' => 'Titel (optional)',
			'channel.writeComment' => 'Kommentar schreiben...',
			'channel.info' => 'Kanalinformationen',
			'channel.settings' => 'Kanaleinstellungen',
			'channel.inviteAdmins' => 'Admins einladen',
			'channel.shareToMyStatus' => 'In meinem Status teilen',
			'channel.creator' => 'Ersteller',
			'channel.admin' => 'Admin',
			'channel.editor' => 'Redakteur',
			'channel.privacyTitle' => 'Öffentliche Kanäle & Datenschutz',
			'channel.privacyDesc' => 'Jeder kann diesen Kanal finden und abonnieren. Ihre Telefonnummer bleibt für andere Abonnenten und Kanal-Admins vollständig verborgen.',
			'channel.aboutThisChannel' => 'Über diesen Kanal',
			'channel.changePhoto' => 'Foto ändern',
			'channel.addPhoto' => 'Foto hinzufügen',
			'channel.addDescription' => 'Beschreibung hinzufügen',
			'channel.channelCreated' => ({required Object name}) => 'Kanal „${name}“ erstellt',
			'channel.startGrowing' => ({required Object name}) => 'Wachse mit „${name}“',
			'channel.shareInviteText' => ({required Object name, required Object url}) => 'Folgt gerne meinem Kanal "${name}": ${url}',
			'channel.discussion' => 'Diskussion',
			'channel.joinDiscussion' => 'Diskussion beitreten',
			'channel.discussionIneligible' => 'Abonnieren Sie diesen Kanal, um seiner Diskussionsgruppe beizutreten',
			'channel.essence' => 'Highlights',
			'channel.allPosts' => 'Alle Beiträge',
			'channel.editPostTags' => 'Tags bearbeiten',
			'channel.linkTitle' => 'Kanal-Link',
			'channel.copyLink' => 'Link kopieren',
			'channel.shareLink' => 'Link teilen',
			'channel.linkAccessHint' => 'Der Link öffnet den Kanal. Zugriff und Abonnements unterliegen weiterhin den Kanalberechtigungen. Unternehmenskanäle erfordern eine berechtigte Mitgliedschaft.',
			'channel.personalChannelLabel' => 'Persönlicher Kanal',
			'channel.enterpriseChannelLabel' => 'Interner Unternehmenskanal',
			'channel.subscribePending' => 'Abonniert; wird aktualisiert',
			'channel.subscribeRefresh' => 'Abonnement aktualisieren',
			'channel.unseenUpdatesBanner' => ({required Object count}) => '${count} neue Updates',
			'chat.bankCard' => 'Bankkarte',
			'chat.receivePayment' => 'Empfangen & Zahlen',
			'chat.alreadyMember' => 'Bereits Mitglied',
			'chat.awaitingReply' => 'Warten auf Antwort',
			'chat.businessCard' => 'Visitenkarte',
			'chat.busyTryAgainLater' => 'Der Gesprächspartner ist beschäftigt, bitte versuchen Sie es später erneut',
			'chat.later' => 'Später',
			'chat.peerIsTyping' => ({required Object name}) => '${name} tippt...',
			'chat.chatHoldDownTalk' => 'Zum Sprechen gedrückt halten',
			'chat.chatMessage' => 'Chatnachrichten',
			'chat.chatSettingMute' => 'Nachrichten stummschalten',
			'chat.chatSettingMuted' => 'Stummschaltung aktiviert',
			'chat.chatSettingUnmuted' => 'Stummschaltung deaktiviert',
			'chat.chatStatusSending' => 'Wird gesendet',
			'chat.chatStatusSent' => 'Gesendet',
			'chat.chatStatusDelivered' => 'Zugestellt',
			'chat.chatStatusSeen' => 'Gelesen',
			'chat.createGroupF2f' => 'Face-to-Face Gruppe erstellen',
			'chat.displayProfile' => 'Mein Profil anzeigen',
			'chat.file' => 'Datei',
			'chat.unknownFile' => 'Unbekannte Datei',
			'chat.fileSize' => 'Dateigröße',
			'chat.forward' => 'Weiterleiten',
			'chat.forwardTo' => 'Weiterleiten an',
			'chat.forwardToFriend' => 'An Freund weiterleiten',
			'chat.forwardedToChats' => ({required Object count}) => 'An ${count} Chats weitergeleitet',
			'chat.great' => 'Ausgezeichnet',
			'chat.groupFile' => 'Gruppendateien',
			'chat.groupFileImagePreview' => 'Bildvorschau',
			'chat.groupFileVideoPreview' => 'Videovorschau',
			'chat.groupFileAudioPreview' => 'Audiovorschau',
			'chat.groupFileMediaPause' => 'Pause',
			'chat.groupFileMediaPlay' => 'Wiedergabe',
			'chat.groupFileUrlMissing' => 'Dateiadresse fehlt, kann nicht geöffnet werden',
			'chat.groupFileUrlInvalid' => 'Dateiadresse ungültig',
			'chat.groupFilePreview' => 'Dateivorschau',
			'chat.groupFileUnnamed' => 'Unbenannte Datei',
			'chat.groupFileCategoryEmpty' => ({required Object category}) => '${category}: Keine Dateien',
			'chat.groupFileEmpty' => 'Keine Gruppendateien',
			'chat.groupFileCategoryDoc' => 'Dokument',
			'chat.groupFileCategoryImage' => 'Bild',
			'chat.groupFileCategoryVideo' => 'Video',
			'chat.groupFileCategoryAudio' => 'Audio',
			'chat.groupFileCategoryOther' => 'Sonstiges',
			'chat.groupChat' => 'Gruppenchat',
			'chat.image' => 'Bild',
			'chat.imageMessage' => '[Bild]',
			'chat.initiateChat' => 'Gruppenchat starten',
			'chat.exportMyData' => 'Meine Daten exportieren',
			'chat.exportDataDesc' => 'Persönliche Daten, Kontakte und Chat-Verlauf exportieren',
			'chat.customMessage' => 'Benutzerdefinierte Nachricht',
			'chat.card' => 'Karte',
			'chat.messageWasWithdrawn' => 'hat eine Nachricht zurückgerufen',
			'chat.messageWasWithdrawnWithTitle' => ({required Object param}) => '${param} hat eine Nachricht zurückgerufen',
			'chat.offline' => 'Offline',
			'chat.online' => 'Online',
			'chat.paramAlreadyExist' => ({required Object param}) => '${param} existiert bereits',
			'chat.pin' => 'Anheften',
			'chat.pinned' => 'Angepinnt',
			'chat.rating' => 'Bewertung',
			'chat.readAgreeParam' => ({required Object param}) => 'Habe gelesen und zugestimmt ${param}',
			'chat.remindMeLater' => 'Später erinnern',
			'chat.quickReplyManage' => 'Schnellantworten verwalten',
			'chat.quickReplyEmpty' => 'Keine Schnellantworten. Unten rechts tippen zum Hinzufügen',
			'chat.quickReplyDuplicate' => 'Inhalt existiert bereits',
			'chat.quickReplyMaxReached' => ({required Object max}) => 'Max. ${max} Einträge',
			'chat.quickReplyHint' => 'Inhalt eingeben...',
			'chat.muteMember' => 'Mitglied stummschalten',
			'chat.unmuteMember' => 'Stummschaltung aufheben',
			'chat.muted' => 'Stummgeschaltet',
			'chat.mutedFor' => ({required Object label}) => 'Stummgeschaltet: ${label}',
			'chat.muteUnitMinutes' => ({required Object count}) => '${count} Min.',
			'chat.muteUnitHours' => ({required Object count}) => '${count} Std.',
			'chat.muteUnitDays' => ({required Object count}) => '${count} Tage',
			'chat.youAreMuted' => 'Sie wurden stummgeschaltet',
			'chat.youAreMutedWithTime' => ({required Object minutes}) => 'Sie sind stummgeschaltet, noch ${minutes} Min.',
			'chat.repliedAt' => 'Geantwortet am',
			'chat.reply' => 'Antworten',
			'chat.resendCode' => 'Code erneut senden',
			'chat.revoke' => 'Widerrufen',
			'chat.scanQrCodeBusinessCard' => 'QR-Code-Visitenkarte scannen',
			'chat.privateChat' => 'Privatchat',
			'chat.sendFriendRequest' => 'Freundschaftsanfrage senden',
			'chat.sendMsgRejected' => 'Nachricht gesendet, aber vom Gesprächspartner abgelehnt.',
			'chat.sendMessage' => 'Nachricht senden',
			'chat.sendTo' => 'Senden an',
			'chat.send' => _root.common.buttonSend,
			'chat.sending' => 'Wird gesendet...',
			'chat.socialProfile' => 'Soziales Profil',
			'chat.sureOpenTheFile' => 'Datei öffnen?',
			'chat.titleMessage' => 'Nachrichten',
			'chat.unpin' => 'Anheftung aufheben',
			'chat.userData' => 'Benutzerdaten',
			'chat.video' => 'Video',
			'chat.videoMessage' => '[Video]',
			'chat.viewAttachments' => 'Anhänge anzeigen',
			'chat.viewLargeImage' => 'Großes Bild ansehen',
			'chat.voice' => 'Sprache',
			'chat.voiceMessage' => 'Sprachnachricht',
			'chat.youWithdrewAMessage' => 'Sie haben eine Nachricht widerrufen',
			'chat.formatCheck' => 'Formatprüfung',
			'chat.featureRequest' => 'Funktionsanfrage',
			'chat.chatResend' => 'Erneut senden',
			'chat.profileExportProfile' => 'Profil exportieren',
			'chat.momentsSend' => 'Senden',
			'chat.loginExpiredMessage' => 'Anmeldung abgelaufen, bitte erneut anmelden',
			'chat.customImage' => 'Benutzerdefiniertes Bild',
			'chat.burnAfterReading' => 'Nach dem Lesen vernichten',
			'chat.goodReadability' => 'Gute Lesbarkeit',
			'chat.profileCompleteness' => 'Profil-Vollständigkeit',
			'chat.tagStatistics' => 'Tag-Statistik',
			'chat.unsupportedMessageType' => 'Nicht unterstützter Nachrichtentyp',
			'chat.passwordMismatch' => 'Passwörter stimmen nicht überein',
			'chat.pleaseTryAgainLater' => 'Bitte versuchen Sie es später erneut',
			'chat.historyUnavailable' => 'Verlaufsnachrichten vorübergehend nicht verfügbar',
			'chat.historyUnavailableHint' => 'Serverseitiges Verlaufsarchiv ist deaktiviert oder nicht verfügbar. Tippen Sie auf Erneut versuchen, um die Synchronisierung neu zu starten',
			'chat.momentsRecordVideo' => 'Video aufnehmen',
			_ => null,
		} ?? switch (path) {
			'chat.momentsVisibilityPrivate' => 'Nur ich',
			'chat.momentsMediaTooManyImages' => 'Max. 9 Bilder auswählbar',
			'chat.momentsMediaTooManyVideos' => 'Max. 1 Video auswählbar',
			'chat.momentsMediaMixedImageAndVideo' => 'Bilder und Video nicht gleichzeitig',
			'chat.momentsReplyPrefix' => 'Antwort @',
			'chat.momentsReplySeparator' => '：',
			'chat.momentsReplyingTo' => 'Antwort an @{name}',
			'chat.sendNewMessage' => 'Neue Nachricht senden',
			'chat.markRead' => 'Als gelesen markieren',
			'chat.markUnread' => 'Als ungelesen markieren',
			'chat.manualPendingBadge' => 'Ausstehend',
			'chat.cancelManualPending' => 'Ausstehend aufheben',
			'chat.manualPendingOff' => 'Nicht ausstehend',
			'chat.manualPendingConflict' => ({required Object param}) => 'Aktueller Serverstatus: ${param}',
			'chat.pleaseEnterSignature' => 'Persönliche Signatur eingeben',
			'chat.exportProfile' => 'Profil exportieren',
			'chat.setSignature' => 'Signatur festlegen',
			'chat.setAvatar' => 'Avatar festlegen',
			'chat.fastForward' => ({required Object seconds}) => 'Schnell vor ${seconds} Sekunden',
			'chat.messageId' => 'Nachrichten-ID',
			'chat.chatType' => 'Chat-Typ',
			'chat.deletingMessage' => 'Wird gelöscht...',
			'chat.deletingLocalMessage' => 'Lokale Nachricht wird gelöscht...',
			'chat.quickReplyReceived' => 'Erhalten',
			'chat.quickReplyThanks' => 'Danke',
			'chat.quickReplyWait' => 'Einen Moment',
			'chat.groupCategoryGroupCount' => ({required Object count}) => '${count} Gruppen',
			'chat.groupAlbumCreateTitle' => 'Gruppenalbum erstellen',
			'chat.groupAlbumCreated' => 'Album erstellt',
			'chat.profileCompleted' => 'Profil vollständig!',
			'chat.profileProgress' => ({required Object percent}) => '${percent}% vollständig',
			'chat.createdAtLabel' => ({required Object time}) => 'Erstellt: ${time}',
			'chat.expiredAtLabel' => ({required Object time}) => 'Gültig bis: ${time}',
			'chat.myReceivedTab' => 'Erhalten',
			'chat.orderStatusLabel' => ({required Object status}) => 'Status: ${status}',
			'chat.orderCreatedAtLabel' => ({required Object time}) => 'Erstellt: ${time}',
			'chat.orderPaymentAtLabel' => ({required Object time}) => 'Bezahlt: ${time}',
			'chat.orderStatusPending' => 'Offen',
			'chat.orderStatusPaid' => 'Bezahlt',
			'chat.orderStatusRefunded' => 'Erstattet',
			'chat.orderStatusExpired' => 'Abgelaufen',
			'chat.defaultFileName' => 'Datei',
			'chat.fileUrlInvalid' => 'Dateilink ungültig',
			'chat.e2eeStatusAvailable' => 'Verfügbar',
			'chat.e2eeGenerateNewKey' => 'Neuen Schlüssel erstellen',
			'chat.e2eeGenerateNewKeyDesc' => 'Neues E2EE-Schlüsselpaar erstellen (alte Nachrichten nicht mehr entschlüsselbar)',
			'chat.e2eeActivated' => 'Aktiv',
			'chat.e2eeCreatedAtLabel' => 'Erstellt am',
			'chat.e2eeGeneratingKey' => 'Schlüssel wird erstellt, bitte warten...',
			'chat.e2eeNewKeyGenerated' => 'Neues E2EE-Schlüsselpaar erstellt!',
			'chat.webFeatureMultiDevice' => 'Multi-Geräte-Sync',
			'chat.webFeatureMultiDeviceDesc' => 'Nahtlos zwischen Handy und PC wechseln, Nachrichten in Echtzeit synchronisieren',
			'chat.webFeatureE2EE' => 'E2EE',
			'chat.webFeatureE2EEDesc' => 'Alle Nachrichten E2EE-verschlüsselt für maximale Privatsphäre',
			'chat.webFeatureFileTransfer' => 'Dateiübertragung',
			'chat.webFeatureFileTransferDesc' => 'Dateien per Drag & Drop senden, alle Formate',
			'chat.webQRStatusWaiting' => 'ImBoy-App öffnen > Einstellungen > Scannen',
			'chat.webQRStatusScanned' => 'Am Handy „Anmelden" antippen',
			'chat.webQRStatusVerifying' => 'Wird geprüft...',
			'chat.webQRStatusExpired' => 'Aktualisieren und erneut scannen',
			'chat.e2eeErrInvalidFormat' => 'Ungültiges Nachrichtenformat, Verschlüsselung fehlgeschlagen',
			'chat.e2eeRecreatingKey' => 'Schlüssel wird neu erstellt...',
			'chat.e2eeKeyRecreated' => 'Schlüssel neu erstellt',
			'chat.e2eeRecoveryNewDeviceTitle' => 'Neue Gerätenutzung erkannt',
			'chat.e2eeRecoveryNewDeviceBody' => 'Zum Schutz Ihrer Nachrichten wurde auf diesem Gerät ein neuer Ende-zu-Ende-Verschlüsselungsschlüssel erzeugt.\n\nÄltere Nachrichten wurden mit dem Schlüssel des alten Geräts verschlüsselt und sind erst nach Wiederherstellung des Schlüssels sichtbar. Sie können ihn über „Lokales Backup importieren“ wiederherstellen.',
			'chat.e2eeRecoveryDecryptFailedTitle' => 'Diese Nachricht kann nicht entschlüsselt werden',
			'chat.e2eeRecoveryDecryptFailedBody' => 'Diese Nachricht wurde mit dem Schlüssel eines anderen Geräts verschlüsselt.\n\nWenn Sie das Gerät gewechselt oder die App neu installiert haben, stellen Sie den Schlüssel wieder her, um ältere Nachrichten zu lesen.',
			'chat.e2eeRecoveryLater' => 'Später',
			'chat.e2eeRecoveryGoRecover' => 'Wiederherstellen',
			'chat.e2eeRecoveryBannerText' => 'Verschlüsselte ältere Nachrichten erkannt. Schlüssel zum Anzeigen wiederherstellen. Tippen für Wiederherstellung.',
			'chat.liveRoomCreateTitle' => 'Livestream erstellen',
			'chat.liveRoomCreating' => 'Wird erstellt...',
			'chat.liveRoomWatch' => 'Ansehen',
			'chat.switchToVoiceInput' => 'Zur Spracheingabe wechseln',
			'chat.switchToKeyboardInput' => 'Zur Tastatureingabe wechseln',
			'chat.extraItems' => 'Extras',
			'chat.messageInputHint' => 'Nachricht schreiben ...',
			'chat.invalidMessageType' => '[Nicht unterstützte Nachricht]',
			'chat.burnReadBadge' => 'Selbstlöschend',
			'chat.convertToText' => 'In Text umwandeln',
			'chat.releaseConvertToText' => 'Loslassen: In Text umwandeln',
			'chat.voiceReleaseCancel' => 'Loslassen: Abbrechen',
			'chat.voiceReleaseCancelSend' => 'Loslassen: Senden abbrechen',
			'chat.voiceSlideHint' => 'Nach oben wischen: Abbrechen / In Text umwandeln',
			'chat.alipayLoginInterrupted' => 'Alipay-Anmeldung vom System unterbrochen, bitte erneut versuchen',
			'chat.encryptedMessagePlaceholder' => '[Verschlüsselte Nachricht]',
			'chat.e2eeDecryptStoreUnavailable' => 'Der verschlüsselte Speicher ist vorübergehend nicht zugänglich; diese Nachricht konnte nicht entschlüsselt werden. Bitte starten Sie die App neu und versuchen Sie es erneut',
			'chat.invalidMessagePlaceholder' => '[Ungültige Nachricht]',
			'chat.videoCallPlaceholder' => '[Videoanruf]',
			'chat.voiceCallPlaceholder' => '[Sprachanruf]',
			'chat.notFriendCannotSend' => 'Keine Freundschaft, Senden nicht möglich',
			'common.about' => 'Über',
			'common.aboutApp' => 'Über die App',
			'common.accept' => 'Akzeptieren',
			'common.acceptFriendRequest' => 'Freundschaftsanfrage bestätigen',
			'common.addFriend' => 'Freund hinzufügen',
			'common.dataNotFound' => 'Die Daten dieser Seite fehlen oder sind abgelaufen',
			'common.smallChange' => 'Kleingeld',
			'common.addTag' => 'Tag hinzufügen',
			'common.addToContacts' => 'Zu Kontakten hinzufügen',
			'common.addToDenylist' => 'Zur Sperrliste hinzufügen',
			'common.added' => 'Hinzugefügt',
			'common.addedToDenylistTips' => 'Zur Sperrliste hinzugefügt. Sie erhalten keine Nachrichten mehr von dieser Person.',
			'common.all' => 'Alle',
			'common.allTime' => 'Gesamter Zeitraum',
			'common.allTypes' => 'Alle Typen',
			'common.allowSearchMe' => 'Suche nach mir erlauben',
			'common.allowedBeSearched' => 'Kürzlich registrierte Freunde, die gefunden werden dürfen',
			'common.appSizeTips' => 'Erforderliche App-Dateien: APK, Compiler-Ausgabe, native Bibliotheken.',
			'common.applyAddFriend' => 'Freund hinzufügen beantragen',
			'common.awaitingVerification' => 'Warten auf Bestätigung',
			'common.buttonAccomplish' => 'Fertig',
			'common.buttonAdd' => 'Hinzufügen',
			'common.buttonBack' => 'Zurück',
			'common.bindMobileAndEmailTips' => 'Verbinden Sie Ihre Mobilfunknummer und E-Mail, um Ihr Konto sicherer zu machen',
			'common.bindNow' => 'Jetzt verbinden',
			'common.buttonCancel' => 'Abbrechen',
			'common.buttonCreate' => 'Erstellen',
			'common.phoneInputHint' => 'Telefonnummer eingeben',
			'common.buttonMore' => 'Mehr',
			'common.buttonRefresh' => 'Aktualisieren',
			'common.buttonClose' => 'Schließen',
			'common.buttonConfirm' => 'Bestätigen',
			'common.buttonContinue' => 'Fortfahren',
			'common.buttonCopy' => 'Kopieren',
			'common.buttonDelete' => 'Löschen',
			'common.buttonLogout' => 'Abmelden',
			'common.buttonOk' => 'OK',
			'common.buttonRetry' => 'Wiederholen',
			'common.buttonSave' => 'Speichern',
			'common.buttonSelectFromAlbum' => 'Aus Album auswählen',
			'common.buttonSend' => 'Senden',
			'common.buttonTakingPictures' => 'Foto aufnehmen',
			'common.cacheTips' => 'Temporäre App-Daten. Bereinigung beeinflusst Nutzung nicht.',
			'common.callDuration' => 'Anrufdauer',
			'common.callEnded' => 'Anruf beendet',
			'common.calling' => 'Im Gespräch',
			'common.cancel' => _root.common.buttonCancel,
			'common.ok' => _root.common.buttonOk,
			'common.operationSuccessful' => 'Erfolgreich',
			'common.save' => _root.common.buttonSave,
			'common.reset' => 'Zurücksetzen',
			'common.clear' => 'Leeren',
			'common.saveTag' => ({required Object count}) => 'Tags speichern (${count})',
			'common.cancelLogoutBody' => 'Konto in Widerrufsfrist. Anmeldung = Löschung stornieren. Für Löschung: 15 Tage nach Antrag nicht anmelden.',
			'common.cancelLogoutTitle' => 'Löschvorgang abbrechen?',
			'common.cancelled' => 'Abgebrochen',
			'common.chatSettingBackground' => 'Chat-Hintergrund',
			'common.chatSettingPinnedSuccess' => 'Erfolgreich angepinnt',
			'common.chatSettingUnpinnedSuccess' => 'Anheftung aufgehoben',
			'common.chatSettings' => 'Chat-Einstellungen',
			'common.chatStatusFailed' => 'Fehlgeschlagen',
			'common.chatErrorInDenylist' => 'Sie stehen auf der Sperrliste',
			'common.checkForUpdates' => 'Auf Updates prüfen',
			'common.clearAll' => 'Alle entfernen',
			'common.clearChatRecord' => 'Chat-Verlauf leeren',
			'common.complaintSuccess' => 'Meldung gesendet',
			'common.complaintFailed' => 'Meldung fehlgeschlagen. Bitte später erneut versuchen.',
			'common.confirmDeleteChatRecord' => 'Chat-Verlauf löschen?',
			'common.confirmRecoverSuccess' => 'Passwort erfolgreich geändert.',
			'common.contactSetting' => 'Kontakteinstellungen',
			'common.contactTags' => 'Kontakt-Tags',
			'common.contactInfoNotSynced' => 'Kontaktinformationen nicht synchronisiert',
			'common.continueDownloading' => 'Download fortsetzen',
			'common.copy' => 'Kopieren',
			'common.createGroupF2fConfirmTips' => 'Diese Freunde treten ebenfalls den Gruppenchat bei',
			'common.createGroupF2fTips' => 'Geben Sie dieselben vier Ziffern wie Freunde in Ihrer Nähe ein, um denselben Gruppenchat beizutreten',
			'common.delete' => _root.common.buttonDelete,
			'common.deleteCollectConfirmDesc' => 'Nach dem Löschen kann nicht wiederhergestellt werden. Möchten Sie diesen Favoriten wirklich löschen?',
			'common.deleteContact' => 'Kontakt löschen',
			'common.deleteForEveryone' => 'Für alle löschen',
			'common.deleteForMe' => 'Für mich löschen',
			'common.deleteTagTips' => 'Nach dem Löschen des Tags werden die Kontakte im Tag nicht gelöscht',
			'common.deleteThisDevice' => 'Dieses Gerät löschen',
			'common.deleteThisDeviceTips' => 'Nach Löschen ist bei nächster Anmeldung auf diesem Gerät eine Sicherheitsüberprüfung erforderlich.',
			'common.denylistNoteDesc' => 'Blockierte Benutzer können Ihnen keine Nachrichten senden und Ihre Beiträge nicht sehen. Tippen Sie auf den Benutzer, um Details anzuzeigen.',
			'common.denylistNoteTitle' => 'Erklärung zur Sperrliste',
			'common.details' => 'Details',
			'common.deviceDetails' => 'Gerätedetails',
			'common.downloaded' => 'Heruntergeladen',
			'common.edit' => 'Bearbeiten',
			'common.editTag' => 'Tag bearbeiten',
			'common.errorEmptyDirectory' => ({required Object param}) => '${param} ist leer',
			'common.errorFailedConnectServer' => _root.common.error,
			'common.errorHttpNotSupported' => _root.common.error,
			'common.errorInternalServer' => _root.common.error,
			'common.errorInvalid' => ({required Object param}) => '${param} ist ungültig',
			'common.errorInvalidRequest' => _root.common.error,
			'common.errorLengthBetween' => ({required Object param, required Object min, required Object max}) => 'Die Länge von ${param} muss zwischen ${min} und ${max} liegen',
			'common.errorManyRequest' => _root.common.error,
			'common.errorPassword' => 'Falsches Passwort',
			'common.errorRequestForbidden' => _root.common.error,
			'common.errorRequestSyntax' => _root.common.error,
			'common.errorRequired' => ({required Object param}) => '${param} ist erforderlich',
			'common.errorRetypePassword' => _root.common.error,
			'common.errorServerDown' => _root.common.error,
			'common.errorServerRefused' => _root.common.error,
			'common.errorUnexpected' => _root.common.error,
			'common.failedGetLatLong' => _root.common.errorNetwork,
			'common.failedGetMapTryAgain' => _root.common.errorNetwork,
			'common.failedRequestPleaseCheckNetwork' => _root.common.errorNetwork,
			'common.feedback' => 'Feedback und Vorschläge',
			'common.feedbackContentRequired' => 'Feedback-Inhalt darf nicht leer sein',
			'common.feedbackDetails' => 'Feedback-Details',
			'common.feedbackSuccessMsg' => 'Feedback erhalten. Wir werden es schnell bearbeiten!',
			'common.followSystemTips' => 'Nach Aktivierung wird der Dunkel-Modus entsprechend dem System ein- oder ausgeschaltet',
			'common.genderUpdateFailed' => 'Geschlechtseinstellung fehlgeschlagen, bitte versuchen Sie es erneut',
			'common.groupAnnouncement' => 'Gruppenankündigung',
			'common.groupFileUploadSuccess' => 'Datei hochgeladen',
			'common.groupFileUploadFailed' => 'Upload fehlgeschlagen. Bitte später erneut versuchen.',
			'common.groupFileDeleteSuccess' => 'Datei gelöscht',
			'common.groupFileDeleteFailed' => 'Löschen fehlgeschlagen. Bitte später erneut versuchen.',
			'common.groupFileUploadTooltip' => 'Datei hochladen',
			'common.groupFileSearch' => 'Gruppendateien durchsuchen',
			'common.groupFileReadFailed' => 'Datei konnte nicht gelesen werden. Bitte erneut versuchen.',
			'common.groupFileDeleteTitle' => 'Gruppendatei löschen',
			'common.groupFileDeleteConfirm' => ({required Object name}) => 'Datei „${name}" wirklich löschen?',
			'common.groupFileImageLoadFailed' => 'Bild konnte nicht geladen werden',
			'common.groupFileOpenFailed' => 'Dateilink kann nicht geöffnet werden',
			'common.groupFileCategoryAll' => 'Alle',
			'common.groupFileSearchEmpty' => 'Keine passenden Dateien gefunden',
			'common.groupFileAudioLoadFailed' => 'Audio konnte nicht geladen werden',
			'common.groupFileAudioLoading' => 'Audio wird geladen...',
			'common.groupQrcodeTips' => ({required Object days, required Object date}) => 'Dieser QR-Code ist ${days} Tage gültig (bis ${date}), wird beim erneuten Betreten aktualisiert',
			'common.helpDocument' => 'Hilfe-Dokument',
			'common.incomingCall' => ({required Object param}) => '${param} ruft an',
			'common.installNow' => 'Jetzt installieren',
			'common.iosAppIdUnknown' => ({required Object param}) => 'AppStore nicht gelistet oder AppID [${param}] existiert nicht',
			'common.koKr' => 'Koreanisch (Südkorea)',
			'common.languageSetting' => 'Spracheinstellung',
			'common.lastActiveTips' => 'Bei sicherem Gerät wird die Anmeldezeit automatisch verlängert, um Freundenachrichten-Empfang/-Versand aufrechtzuerhalten. Die letzte Aktivitätszeit wird aktualisiert.',
			'common.lastSeenJustNow' => 'Gerade online',
			'common.lastSeenLongTimeAgo' => 'Vor langer Zeit online',
			'common.lastSeenMonthsAgo' => ({required Object param}) => 'Vor ${param} Monaten',
			'common.loadError' => 'Laden fehlgeschlagen, bitte versuchen Sie es erneut',
			'common.loadMore' => 'Mehr laden',
			'common.loading' => 'Wird geladen',
			'common.locationMessage' => 'Standortnachricht',
			'common.loginDeviceManagementTips' => 'Konto auf folgenden Geräten angemeldet. Sie können Geräte löschen. Nach Löschen ist bei nächster Anmeldung auf diesem Gerät eine Sicherheitsüberprüfung erforderlich.',
			'common.logoutFailed' => 'Abmelden fehlgeschlagen',
			'common.messageCall' => 'Nachricht senden',
			'common.messageContent' => 'Nachrichteninhalt',
			'common.messageRevoked' => 'Nachricht zurückgerufen',
			'common.quoteMessageNotAvailable' => 'Referenzierte Nachricht nicht verfügbar',
			'common.microphone' => 'Mikrofon',
			'common.microphonePermissionNotObtained' => 'Mikrofonberechtigung nicht erteilt',
			'common.moreInfo' => 'Mehr Infos',
			'common.nearbyPeopleTips' => 'Kontaktdaten mit Personen in der Nähe austauschen und neue Freunde kennenlernen',
			'common.needContinueWorkHard' => 'Weiter hart arbeiten',
			'common.networkErrorWithAction' => ({required Object param}) => '${param} fehlgeschlagen, bitte überprüfen Sie Ihre Netzwerkverbindung',
			'common.networkException' => 'Netzwerkverbindungsfehler',
			'common.errorNetwork' => 'Netzwerkfehler',
			'common.networkExceptionPlaseNeedNetworkToViewData' => 'Netzwerkstatus abnormal, Netzwerkverbindung erforderlich, um Daten anzuzeigen',
			'common.newVersionDetected' => 'Neue Version erkannt',
			'common.newVersionDetectedWithVersion' => ({required Object param}) => 'Neue Version erkannt ${param}',
			'common.nextStep' => 'Nächster Schritt',
			'common.nicknameEmojiOnlyError' => 'Spitzname darf nicht nur aus Emojis bestehen',
			'common.nicknameEmptyError' => 'Spitzname darf nicht leer sein',
			'common.nicknameLengthError' => 'Spitznamenlänge sollte zwischen 2-24 Zeichen liegen',
			'common.nicknameSensitiveWordError' => 'Spitzname enthält sensible Wörter, bitte erneut eingeben',
			'common.nicknameUpdateFailed' => 'Spitzname ändern fehlgeschlagen, bitte versuchen Sie es erneut',
			'common.nicknameWhitespaceError' => 'Spitzname darf nicht nur aus Leerzeichen bestehen',
			'common.noAvatar' => 'Kein Avatar',
			'common.noBarcodeFound' => 'Strichcode nicht gefunden!',
			'common.noContacts' => 'Keine Kontakte',
			'common.noConversationMessages' => 'Keine Nachrichten',
			'common.noData' => 'Keine Daten',
			'common.noMembersInCurrentTag' => 'Keine Mitglieder im aktuellen Tag',
			'common.noNewFriends' => 'Keine neuen Freunde',
			'common.noPermission' => 'Keine Berechtigung',
			'common.noReply' => 'Keine Antwort',
			'common.noUpdateDescription' => 'Keine Update-Beschreibung',
			'common.notAuthorizedLatLong' => 'Berechtigung für Standortabfrage noch nicht erteilt',
			'common.notLoggedIn' => 'Nicht angemeldet',
			'common.notBad' => 'Nicht schlecht',
			'common.notBound' => 'Nicht gebunden',
			'common.notFilled' => 'Nicht ausgefüllt',
			'common.notInstallAnyMapApp' => 'Sie haben keine Karten-App installiert',
			'common.notReceiveCoeQ' => 'Keinen Bestätigungscode erhalten?',
			'common.notSet' => 'Nicht eingestellt',
			'common.notTurnedLocationService' => 'Sie haben den Standortdienst noch nicht aktiviert',
			'common.nowNewVersion' => 'Keine neue Version erkannt',
			'common.offlineNotification' => 'Offline-Benachrichtigung',
			'common.operationFailedAgainLater' => 'Operation fehlgeschlagen, bitte versuchen Sie es später erneut',
			'common.pauseDownloading' => 'Download pausieren',
			'common.peerNoResponse' => 'Gesprächspartner antwortet nicht...',
			'common.permissionAcquisitionFailed' => 'Berechtigung konnte nicht erteilt werden',
			'common.personalCard' => 'Persönliche Visitenkarte',
			'common.personalInformation' => 'Persönliche Informationen',
			'common.pinCodeFillTips' => 'Bitte füllen Sie alle Felder aus',
			'common.profileSettings' => 'Profil-Einstellungen',
			'common.reEdit' => 'Erneut bearbeiten',
			'common.regionSearchHint' => 'Nach Regionsname suchen',
			'common.regionSelectedLevelHint' => ({required Object region, required Object level}) => 'Ausgewählt: ${region} (Ebene ${level}). Sie können jetzt fertigstellen oder weiter eingrenzen.',
			'common.releaseFingerCancelSending' => 'Finger nach oben wischen, um das Senden abzubrechen',
			'common.removeContactFromTag' => 'Kontakt aus Tag entfernen',
			'common.removeMember' => 'Mitglied entfernen',
			'common.atMentionYouTag' => '[@dir] ',
			'common.atMentionLeftMember' => '@ausgetretenes Mitglied',
			'common.muteNotifications' => 'Benachrichtigungen stummschalten',
			'common.muteNotificationsHint' => 'Bei Aktivierung erhalten Sie keine Benachrichtigungen, sehen aber ungelesene Nachrichten in der Chat-Liste',
			'common.revokeExpired' => 'Mehr als 2 Minuten, Widerruf nicht möglich',
			'common.quickReplyAddTitle' => 'Schnellantwort hinzufügen',
			'common.quickReplyEditTitle' => 'Schnellantwort bearbeiten',
			'common.removeAdmin' => 'Admin entfernen',
			'common.setAdminConfirm' => 'Dieses Mitglied als Admin festlegen?',
			'common.removeAdminConfirm' => 'Admin-Rolle dieses Mitglieds entziehen?',
			'common.unmuteMemberConfirm' => 'Stummschaltung dieses Mitglieds aufheben?',
			'common.kickMemberConfirm' => 'Dieses Mitglied aus der Gruppe entfernen?',
			'common.setAdminSuccess' => 'Admin festgelegt',
			'common.setAdminFailed' => 'Admin konnte nicht festgelegt werden',
			'common.removeAdminSuccess' => 'Admin entfernt',
			'common.removeAdminFailed' => 'Admin konnte nicht entfernt werden',
			'common.muteMemberSuccess' => 'Mitglied stummgeschaltet',
			'common.muteMemberFailed' => 'Stummschalten fehlgeschlagen',
			'common.unmuteMemberSuccess' => 'Stummschaltung aufgehoben',
			'common.unmuteMemberFailed' => 'Aufheben der Stummschaltung fehlgeschlagen',
			'common.kickMemberSuccess' => 'Mitglied entfernt',
			'common.kickMemberFailed' => 'Mitglied konnte nicht entfernt werden',
			'common.notMuted' => 'Nicht stummgeschaltet',
			'common.muteDuration' => 'Stummschaltungsdauer',
			'common.muteDuration1hour' => '1 Stunde',
			'common.muteDuration1day' => '1 Tag',
			'common.muteDuration7days' => '7 Tage',
			'common.muteDuration5min' => '5 Min.',
			'common.muteDuration10min' => '10 Min.',
			'common.muteDuration30min' => '30 Min.',
			'common.muteDuration30days' => '30 Tage',
			'common.muteUnitSeconds' => ({required Object count}) => '${count} Sek.',
			'common.throttleWarning' => 'Zu viele Aktionen. Bitte später erneut versuchen.',
			'common.throttleRetryAfter' => ({required Object seconds}) => 'Zu viele Aktionen. Bitte in ${seconds} Sek. erneut versuchen.',
			'common.mutedCannotSend' => 'Während Stummschaltung können keine Nachrichten gesendet werden',
			'common.resetFilters' => 'Filter zurücksetzen',
			'common.saveQrCode' => 'QR-Code speichern',
			'common.saveSuccess' => 'Erfolgreich gespeichert',
			'common.scanQrcodeAddFriend' => 'Scannen Sie den QR-Code, um mich als Freund hinzuzufügen',
			'common.search' => 'Suche',
			'common.searchScope' => 'Suchbereich',
			'common.searchAll' => 'Alle Nachrichten',
			'common.searchChatContent' => 'Chat-Inhalt durchsuchen',
			'common.searchChatRecord' => 'Chat-Verlauf durchsuchen',
			'common.searchError' => 'Suchfehler',
			'common.searchHint' => 'Schlüsselwörter eingeben, um Nachrichten zu suchen',
			'common.searchHistory' => 'Suchverlauf',
			'common.searchLocation' => 'Standort suchen',
			'common.searchMessagesHint' => 'Chat-Inhalt durchsuchen',
			'common.searchNoFound' => 'Keine Suchergebnisse :(',
			'common.searchNoResults' => 'Keine Suchergebnisse',
			'common.noSearchHistory' => 'Kein Suchverlauf',
			'common.searchResults' => 'Suchergebnisse',
			'common.selectAll' => 'Alle auswählen',
			'common.selectContacts' => 'Kontakte auswählen',
			'common.selectedRegion' => 'Ausgewählte Region',
			'common.sendMsgNotFriendTips' => 'Gesprächspartner hat Freundesverifizierung aktiviert. Sie sind noch nicht Freund. Senden Sie zuerst eine Freundesanfrage. Nach Bestätigung können Sie chatten.',
			'common.share' => 'Teilen',
			'common.slideUpCancelSending' => 'Finger nach oben wischen, um das Senden abzubrechen',
			'common.storagePermissionNotObtained' => 'Speicherberechtigung nicht erteilt',
			'common.submittedAt' => 'Eingereicht am',
			'common.sureDeleteData' => 'Löschen bestätigen? Nach dem Löschen kann nicht wiederhergestellt werden.',
			'common.sureDeleteGroupChatRecord' => 'Chat-Verlauf der Gruppe löschen?',
			'common.switchEnvironment' => 'Umgebung wechseln',
			'common.timeDaysAgo' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(n, one: 'Vor ${n} Tag', other: 'Vor ${n} Tagen', ), 
			'common.timeHoursAgo' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(n, one: 'Vor ${n} Stunde', other: 'Vor ${n} Stunden', ), 
			'common.timeJustNow' => 'Gerade eben',
			'common.timeMinutesAgo' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(n, one: 'Vor ${n} Minute', other: 'Vor ${n} Minuten', ), 
			'common.tipConnectDesc' => 'Kein Netzwerk',
			'common.tipConnectDescWithParen' => ({required Object param}) => '(${param})',
			'common.tipDeleteContact' => ({required Object param}) => 'Kontakt "${param}" löschen, gleichzeitig den Chat-Verlauf mit diesem Kontakt löschen',
			'common.tipDeviceSpace' => ({required Object param1, required Object param2}) => 'Belegt ${param1}% des Gerätespeichers(${param2})',
			'common.tipDraft' => 'Entwurf',
			'common.tipFailed' => 'Operation fehlgeschlagen!',
			'common.tipSuccess' => 'Operation erfolgreich!',
			'common.tipTips' => 'Tipps',
			'common.titleContact' => 'Kontakte',
			'common.today' => 'Heute',
			'common.unknown' => 'Unbekannt',
			'common.unknownMessage' => 'Unbekannte Nachricht',
			'common.updateLog' => 'Update-Protokoll',
			'common.updateNow' => 'Jetzt aktualisieren',
			'common.uploading' => 'Wird hochgeladen…',
			'common.uploadSuccess' => 'Hochgeladen',
			'common.uploadFailed' => 'Hochladen fehlgeschlagen',
			'common.userDataTips' => 'Enthält notwendige App-Dateien sowie alle Daten wie Chatnachrichten und Kontakte.',
			'common.userDisabledOrDeleted' => 'Benutzer deaktiviert oder gelöscht',
			'common.userNotExist' => 'Benutzer existiert nicht',
			'common.version' => 'Version',
			'common.videoCall' => 'Videoanruf',
			'common.viewAllGroupMember' => 'Alle Gruppenmitglieder anzeigen',
			'common.voiceCall' => 'Sprachanruf',
			'common.groupCall' => 'Gruppenanruf',
			'common.callDisconnected' => 'Anruf getrennt',
			'common.connecting' => 'Verbinden…',
			'common.voiceInputNotImplemented' => 'Spracheingabe-Funktion noch nicht implementiert',
			'common.waitingDownload' => 'Warten auf Download',
			'common.waitingPeerAccept' => 'Warten auf Annahme durch den Gesprächspartner...',
			'common.warning' => 'Warnung:',
			'common.webpageLoading' => 'Webseite wird geladen...',
			'common.yesterday' => 'Gestern',
			'common.confirmRemoveFromDenylist' => 'Diesen Benutzer wirklich aus der Sperrliste entfernen?',
			'common.buttonRemove' => 'Entfernen',
			'common.removedFromDenylist' => 'Aus der Sperrliste entfernt',
			'common.newEmailAddress' => 'Neue E-Mail-Adresse',
			'common.emailAddress' => 'E-Mail-Adresse',
			'common.enterEmailAddress' => 'E-Mail-Adresse eingeben',
			'common.getVerificationCode' => 'Bestätigungscode erhalten',
			'common.confirmChange' => 'Änderung bestätigen',
			'common.verificationCodeSentToEmail' => 'Bestätigungscode an diese E-Mail gesendet, bitte innerhalb Gültigkeitsdauer bestätigen',
			'common.verificationCodeSentToMobile' => 'Bestätigungscode an diese Mobilfunknummer gesendet, bitte innerhalb Gültigkeitsdauer bestätigen',
			'common.sendFailed' => 'Senden fehlgeschlagen',
			'common.forceOffline' => 'Abmelden',
			'common.forceDeviceOffline' => 'Gerät offline nehmen',
			'common.forceDeviceOfflineConfirm' => 'Offline-Befehl an dieses Gerät senden, fortfahren?',
			'common.confirmForceOffline' => 'Abmelden bestätigen',
			'common.forceOfflineCommandSent' => 'Offline-Befehl gesendet',
			'common.feedbackSlogan' => 'Ihre Vorschläge sind unser Antrieb für Verbesserungen',
			'common.newFeedback' => 'Neues Feedback',
			'common.feedbackHistory' => 'Feedback-Verlauf',
			'common.confirmDelete' => 'Löschen bestätigen',
			'common.verificationCode' => 'Bestätigungscode',
			'common.feedbackContent' => 'Feedback-Inhalt',
			'common.officialReply' => 'Offizielle Antwort',
			'common.setPasswordSecurityTips' => 'Verbessern Sie die Kontosicherheit und vermeiden Sie Anmeldeprobleme ohne Bestätigungscode. Legen Sie ein Anmeldepasswort fest.',
			'common.locationHidden' => 'Ihr Standort ist ausgeblendet',
			'common.locationVisible' => 'Ihr Standort wird angezeigt',
			'common.noNearbyPeople' => 'Keine Personen in der Nähe',
			'common.clickSearchButtonToFind' => 'Tippen Sie oben auf Suchen, um Personen in der Nähe zu finden',
			'common.operationFailed' => _root.common.error,
			'common.featureInDevelopment' => 'Funktion in Entwicklung...',
			'common.addedToDenylist' => 'Zur Sperrliste hinzugefügt',
			'common.groupAnnouncementPublish' => 'Ankündigung veröffentlichen',
			'common.pleaseEnterAnnouncementContent' => 'Bitte Ankündigungsinhalt eingeben',
			'common.selectExpirationDateOptional' => 'Ablaufdatum auswählen (optional)',
			'common.groupAnnouncementDeleteConfirm' => 'Diese Ankündigung wirklich löschen?',
			'common.groupAnnouncementDelete' => 'Löschen',
			'common.groupAnnouncementLoadFailed' => 'Ankündigung konnte nicht geladen werden. Bitte später erneut versuchen.',
			'common.groupAnnouncementPublishFailed' => 'Ankündigung konnte nicht veröffentlicht werden',
			'common.groupAnnouncementPublishSuccess' => 'Ankündigung veröffentlicht',
			'common.groupAnnouncementDeleteFailed' => 'Ankündigung konnte nicht gelöscht werden',
			'common.groupAnnouncementDeleteSuccess' => 'Ankündigung gelöscht',
			'common.privacyClearChatHistory' => 'Chat-Verlauf löschen',
			'common.privacyClearChatHistoryConfirm' => 'Wirklich gesamten Chat-Verlauf löschen? Diese Aktion kann nicht rückgängig gemacht werden.',
			'common.privacyLogoutAccountConfirm' => 'Konto wirklich löschen? Diese Aktion wird Ihr Konto und alle Daten dauerhaft löschen und kann nicht rückgängig gemacht werden.',
			'common.privacySettings' => 'Datenschutz-Einstellungen',
			'common.searchSettings' => 'Sucheinstellungen',
			'common.allowSearchByAccount' => 'Suche nach Konto erlauben',
			'common.allowSearchByAccountDesc' => 'Andere Benutzer können Sie über Ihr Konto finden',
			'common.allowAddByPhone' => 'Über Mobilfunknummer hinzufügen erlauben',
			'common.allowAddByPhoneDesc' => 'Andere Benutzer können Sie über Ihre Mobilfunknummer als Freund hinzufügen',
			'common.allowAddByQR' => 'Über QR-Code hinzufügen erlauben',
			'common.allowAddByQRDesc' => 'Andere Benutzer können Sie durch Scannen Ihres QR-Codes als Freund hinzufügen',
			'common.statusSettings' => 'Status-Einstellungen',
			'common.showOnlineStatus' => 'Online-Status anzeigen',
			'common.showOnlineStatusDesc' => 'Wenn deaktiviert, können Freunde Ihren Online-Status und Ihre letzte Anmeldezeit nicht sehen; die Nachrichtenzustellung ist nicht beeinträchtigt',
			'common.allowNearbyVisible' => 'Für Personen in der Nähe sichtbar',
			'common.dataSettings' => 'Daten-Einstellungen',
			'common.clearChatRecords' => 'Chat-Verläufe löschen',
			'common.clearChatRecordsDesc' => 'Alle Chat-Verläufe löschen, diese Aktion kann nicht rückgängig gemacht werden',
			'common.deleteAccountAction' => 'Konto löschen',
			'common.deleteAccountActionDesc' => 'Konto und alle Daten dauerhaft löschen, diese Aktion kann nicht rückgängig gemacht werden',
			'common.chatHistoryCleared' => 'Chat-Verlauf gelöscht',
			'common.chatDeleteMessage' => 'Nachricht löschen',
			'common.chatCopy' => 'Kopieren',
			'common.chatSaveImage' => 'Bild speichern',
			'common.chatDeleteLocalOnly' => 'Nur lokal löschen',
			'common.chatDeleteFailed' => 'Löschen fehlgeschlagen',
			'common.chatNetworkErrorDeleteLocal' => 'Netzwerkverbindung fehlgeschlagen, nur lokale Nachricht löschen?',
			'common.chatDeleteConfirm' => 'Diese Nachricht wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.',
			'common.chatDeleteOnlyLocal' => 'Nur für Sie löschen, für andere weiterhin sichtbar',
			'common.chatDeleteAll' => 'Für alle löschen, kann nicht rückgängig gemacht werden',
			'common.chatInitFailed' => 'Chat-Initialisierung fehlgeschlagen',
			'common.cameraShootFailed' => 'Aufnahme fehlgeschlagen',
			'common.cameraCapture' => 'Kamera',
			'common.cameraModePhoto' => 'Foto',
			'common.cameraModeVideo' => 'Video',
			'common.cameraRetake' => 'Neu aufnehmen',
			'common.cameraUse' => 'Verwenden',
			'common.cameraNoDevice' => 'Keine Kamera verfügbar',
			'common.avatarEditAvatar' => 'Avatar bearbeiten',
			'common.backgroundUseCustomColor' => 'Benutzerdefinierte Farbe verwenden',
			'common.backgroundOnlySolidColor' => 'Gilt nur für einfarbige Hintergründe',
			'common.backgroundSelectColor' => 'Farbe auswählen',
			'common.profileShareProfile' => 'Profil teilen',
			'common.tagClearAllConfirm' => 'Wirklich alle Tags leeren?',
			'common.tagClearAll' => 'Leeren bestätigen',
			'common.audioPlayFailed' => 'Wiedergabe fehlgeschlagen',
			'common.forcedOfflineByDevice' => ({required Object device}) => 'Sie wurden vom Gerät [${device}] zwangsabgemeldet',
			'common.loadingTagDataFailed' => 'Laden der Tag-Daten fehlgeschlagen',
			'common.pleaseEnterContent' => 'Bitte Inhalt eingeben',
			'common.comingSoon' => 'Demnächst verfügbar',
			'common.backgroundTransparency' => 'Hintergrundtransparenz',
			'common.defaultBackground' => 'Standardhintergrund',
			'common.solidColorBackground' => 'Einfarbiger Hintergrund',
			'common.selectImageFailed' => 'Bildauswahl fehlgeschlagen',
			'common.locationSelectNotImplemented' => 'Standortauswahl-Funktion noch nicht implementiert',
			'common.selectLocationFailed' => 'Standortauswahl fehlgeschlagen',
			'common.sendCardNotImplemented' => 'Kartensendefunktion noch nicht implementiert',
			'common.voiceSendFailed' => 'Sprachnachricht senden fehlgeschlagen',
			'common.featureNotImplemented' => 'Funktion noch nicht implementiert',
			'common.sendCollectionNotImplemented' => 'Sammlungssendefunktion noch nicht implementiert',
			'common.fileOpenNotImplemented' => 'Dateiöffnungsfunktion noch nicht implementiert',
			'common.fileShareNotImplemented' => 'Dateiteilungsfunktion noch nicht implementiert',
			'common.retrySuccess' => 'Wiederholung erfolgreich',
			'common.deleteSuccess' => 'Erfolgreich gelöscht',
			'common.localDeleteSuccess' => 'Lokales Löschen erfolgreich',
			'common.localDeleteFailed' => 'Lokales Löschen fehlgeschlagen',
			'common.revokeSuccess' => 'Erfolgreich widerrufen',
			'common.editContentCannotBeEmpty' => 'Bearbeitungsinhalt darf nicht leer sein',
			'common.editSuccess' => 'Erfolgreich bearbeitet',
			'common.enabled' => 'Aktiviert',
			'common.disabled' => 'Deaktiviert',
			'common.fontSizeSettingUpdated' => 'Schriftgröße-Einstellung aktualisiert',
			'common.fontSizeSetting' => 'Schriftgröße-Einstellung',
			_ => null,
		} ?? switch (path) {
			'common.fontTooSmallMayAffect' => 'Schrift zu klein, kann das Lesen beeinträchtigen',
			'common.dragSliderAdjustFontSize' => 'Schieberegler ziehen, um Schriftgröße anzupassen',
			'common.personalInfo' => 'Persönliche Informationen',
			'common.nicknameNotSet' => 'Spitzname nicht festgelegt',
			'common.basicInfo' => 'Grundlegende Informationen',
			'common.contactInfo' => 'Kontaktinformationen',
			'common.editTags' => 'Tags bearbeiten',
			'common.quickActions' => 'Schnellaktionen',
			'common.noNewFriendRequests' => 'Derzeit keine neuen Freundschaftsanfragen',
			'common.pleaseEnterVerificationMessage' => 'Bitte Bestätigungsnachricht eingeben',
			'common.unknownRegion' => 'Unbekannte Region',
			'common.noCommonGroups' => 'Keine gemeinsamen Gruppen',
			'common.noMoreInfo' => 'Keine weiteren Informationen',
			'common.verificationMessage' => 'Bestätigungsnachricht',
			'common.burnEnabledMessage' => ({required Object duration}) => 'Nach Aktivierung: Nachrichten werden ${duration} nach dem Lesen automatisch zerstört',
			'common.burnDisabledMessage' => 'Nach Deaktivierung: Nachrichten werden nicht automatisch zerstört',
			'common.noGroupAnnouncement' => 'Keine Gruppenankündigung',
			'common.featureComingSoon' => 'Funktion demnächst verfügbar',
			'common.understood' => 'Verstanden',
			'common.noProblem' => 'Kein Problem',
			'common.onMyWay' => 'Bin unterwegs',
			'common.operationOptions' => 'Optionen',
			'common.copyTextContent' => 'Textinhalt kopieren',
			'common.shareWithOtherFriends' => 'Mit anderen Freunden teilen',
			'common.addTagsToFavorites' => 'Tags zu Favoriten hinzufügen',
			'common.addRemarkToFavorites' => 'Bemerkung zu Favoriten hinzufügen',
			'common.deleteThisCollection' => 'Diese Sammlung löschen',
			'common.changeSuccess' => 'Erfolgreich geändert',
			'common.lengthOk' => 'Länge in Ordnung',
			'common.confirmNewPassword' => 'Neues Passwort bestätigen',
			'common.validationPassed' => 'Validierung bestanden',
			'common.momentsContentHint' => 'Etwas schreiben...',
			'common.momentsAddMedia' => 'Medien hinzufügen',
			'common.momentsAllowUidsLabel' => 'Sichtbar für UIDs (kommagetrennt)',
			'common.momentsNoData' => 'Keine Momente',
			'common.momentsDeleteConfirm' => 'Diesen Moment wirklich löschen?',
			'common.momentsDeleteCommentConfirm' => 'Diesen Kommentar wirklich löschen?',
			'common.momentsNotFound' => 'Moment existiert nicht oder keine Berechtigung',
			'common.momentsContentOrMediaRequired' => 'Inhalt oder Medien angeben',
			'common.momentsPublishFailed' => 'Veröffentlichung fehlgeschlagen',
			'common.momentsAllowComment' => 'Kommentare erlauben',
			'common.momentsNoComments' => 'Keine Kommentare',
			'common.momentsCommentFailed' => 'Kommentar fehlgeschlagen. Bitte später erneut versuchen.',
			'common.momentsDeleteFailed' => 'Löschen fehlgeschlagen. Bitte später erneut versuchen.',
			'common.momentsReportSubmitted' => 'Meldung gesendet',
			'common.momentsReportFailed' => 'Meldung fehlgeschlagen. Bitte später erneut versuchen.',
			'common.momentReportReasonSpam' => 'Spam oder Werbung',
			'common.momentReportReasonHarassment' => 'Belästigung',
			'common.momentReportReasonPorn' => 'Pornografie',
			'common.momentReportReasonFraud' => 'Betrug',
			'common.momentReportReasonInfringement' => 'Urheberrechtsverletzung',
			'common.momentReportReasonOther' => 'Sonstiges',
			'common.momentReportReasonPrompt' => 'Grund auswählen',
			'common.momentsLoadMoreComments' => 'Weitere Kommentare laden',
			'common.momentsUploadFailed' => 'Medien-Upload fehlgeschlagen. Bitte später erneut versuchen.',
			'common.saveFailed' => 'Speichern fehlgeschlagen',
			'common.confirm' => 'Bestätigen',
			'common.success' => 'Erfolg',
			'common.personalDisplay' => 'Persönliche Anzeige',
			'common.personalSignature' => 'Persönliche Signatur',
			'common.personalBackground' => 'Persönlicher Hintergrund',
			'common.expression' => 'Emoji',
			'common.extendedInfo' => 'Erweiterte Informationen',
			'common.profession' => 'Beruf',
			'common.shareFailed' => 'Teilen fehlgeschlagen',
			'common.exportSuccessThenCopiedToClipboard' => ({required Object param}) => 'Profil im ${param}-Format exportiert und in die Zwischenablage kopiert',
			'common.setRegion' => 'Region festlegen',
			'common.deleteOperationAbnormal' => 'Löschvorgang anomal, bitte versuchen Sie es erneut',
			'common.revoking' => 'Wird widerrufen...',
			'common.editing' => 'Wird bearbeitet...',
			'common.messageIdCannotBeEmpty' => 'Nachrichten-ID ist leer, Vorgang kann nicht durchgeführt werden',
			'common.startRevokeMessageFlow' => 'Widerruf-Nachrichtenablauf starten',
			'common.revokeMessageTracking' => 'Widerruf-Nachrichtenverfolgung',
			'common.useNewActionMechanism' => 'Neuen Action-Mechanismus verwenden',
			'common.revokeMessageSendResult' => 'Widerruf-Nachrichtensendergebnis',
			'common.revokeRequestSendComplete' => 'Widerruf-Anfrage gesendet',
			'common.revokeFailed' => 'Widerruf fehlgeschlagen',
			'common.revokeMessageException' => 'Widerruf-Nachrichtenausnahme',
			'common.revokeOperationAbnormal' => 'Widerrufsvorgang anomal',
			'common.startEditMessageFlow' => 'Bearbeitungs-Nachrichtenablauf starten',
			'common.editMessageTracking' => 'Bearbeitungs-Nachrichtenverfolgung',
			'common.newContent' => 'Neuer Inhalt',
			'common.editMessageSendResult' => 'Bearbeitungs-Nachrichtensendergebnis',
			'common.editRequestSendComplete' => 'Bearbeitungsanfrage gesendet',
			'common.editFailed' => 'Bearbeitung fehlgeschlagen',
			'common.editMessageException' => 'Bearbeitungs-Nachrichtenausnahme',
			'common.editOperationAbnormal' => 'Bearbeitungsvorgang anomal',
			'common.error' => 'Fehler',
			'common.cannotOpenWebpage' => 'Webseite kann nicht geöffnet werden',
			'common.selectImageFailedWithError' => 'Bildauswahl fehlgeschlagen',
			'common.reactionAdded' => 'Reaktion hinzugefügt',
			'common.reactionCancelled' => 'Reaktion abgebrochen',
			'common.retryFailedPleaseCheckNetwork' => 'Wiederholung fehlgeschlagen, bitte Netzwerkverbindung überprüfen',
			'common.retryAbnormal' => 'Wiederholungsanomalie',
			'common.deleteFailedPleaseTryAgain' => 'Löschen fehlgeschlagen, bitte erneut versuchen',
			'common.deleteFailedPleaseCheckNetwork' => 'Löschen fehlgeschlagen, bitte Netzwerkverbindung überprüfen',
			'common.seconds' => 'Sekunden',
			'common.settingFailedPleaseTryAgain' => 'Einstellung fehlgeschlagen, bitte erneut versuchen',
			'common.partialDeleteSuccess' => ({required Object success, required Object fail}) => 'Teilweises Löschen erfolgreich: ${success} erfolgreich, ${fail} fehlgeschlagen',
			'common.recordingCancelled' => 'Aufnahme abgebrochen',
			'common.pullOfflineMessagesFailed' => 'Abruf von Offline-Nachrichten fehlgeschlagen',
			'common.pullOfflineMessagesAbnormal' => 'Abruf von Offline-Nachrichten fehlgeschlagen',
			'common.logoutRequestFailedPleaseCheckNetwork' => 'Abmeldeanforderung fehlgeschlagen, bitte Netzwerkverbindung überprüfen',
			'common.permissionOnlySupportAndroidAndIos' => 'Berechtigung unterstützt nur Android und iOS',
			'common.retryingSend' => 'Wiederholung wird gesendet...',
			'common.quickReplyOk' => 'Okay',
			'common.quickReplyOkThanks' => 'OK, danke',
			'common.noDetailedInfo' => 'Dieser Benutzer hat keine persönliche Signatur und keine detaillierten Informationen festgelegt',
			'common.noNewRegisteredUsers' => 'Derzeit keine neuen registrierten Benutzer Bitte kommen Sie später zurück',
			'common.newRegisteredUsersTip' => 'Kürzlich registrierte Benutzer werden hier angezeigt, Sie können sie als Freunde hinzufügen',
			'common.notificationFriendRequest' => 'Freundschaftsanfrage',
			'common.notificationFriendRequestBody' => ({required Object requesterName}) => '${requesterName} möchte Sie als Freund hinzufügen',
			'common.notificationGroupInvite' => 'Gruppeneinladung',
			'common.notificationGroupInviteBody' => ({required Object inviterName, required Object groupName}) => '${inviterName} lädt Sie in die Gruppe ${groupName} ein',
			'common.youRevokedMessage' => 'Sie haben eine Nachricht widerrufen',
			'common.otherRevokedMessage' => 'Der Gesprächspartner hat eine Nachricht widerrufen',
			'common.networkFailureTryAgain' => 'Netzwerkfehler, bitte versuchen Sie es erneut!',
			'common.networkNotAvailable' => 'Netzwerk derzeit nicht verfügbar.',
			'common.pleaseCheckNetworkConnection' => 'Bitte überprüfen Sie Ihre Netzwerkverbindung.',
			'common.lastSeenMinutesAgo' => ({required num n}) => _root.common.timeMinutesAgo(n: n),
			'common.lastSeenHoursAgo' => ({required num n}) => _root.common.timeHoursAgo(n: n),
			'common.lastSeenDaysAgo' => ({required num n}) => _root.common.timeDaysAgo(n: n),
			'common.fontSettings' => _root.common.fontSizeSetting,
			'common.noFavoritesYet' => 'Noch keine Favoriten. Sammeln Sie einige interessante Nachrichten!',
			'common.fontPreviewText' => 'Dies ist der Fließtext. Sie können hier sehen, wie verschiedene Schriftgrößen aussehen.',
			'common.smaller' => 'Kleiner',
			'common.currentFontScale' => ({required Object param1, required Object param2}) => 'Aktuell: ${param1} ${param2}%',
			'common.groupAnnouncementExpiry' => ({required Object time}) => 'Gültig bis: ${time}',
			'common.groupAlbumCreateFailed' => 'Erstellen fehlgeschlagen. Bitte später erneut versuchen.',
			'common.groupAlbumDeleteTitle' => 'Gruppenalbum löschen',
			'common.groupAlbumDeleteConfirm' => ({required Object name}) => 'Album „${name}" wirklich löschen?',
			'common.groupAlbumDeleted' => 'Album gelöscht',
			'common.groupAlbumDeleteFailed' => 'Löschen fehlgeschlagen. Bitte später erneut versuchen.',
			'common.groupAlbumRenameFailed' => 'Umbenennen fehlgeschlagen. Bitte später erneut versuchen.',
			'common.groupAlbumUploadTooltip' => 'Bild hochladen',
			'common.groupAlbumDeleteTooltip' => 'Album löschen',
			'common.groupAlbumNoAlbum' => 'Keine Gruppenalben',
			'common.groupAlbumPhotoReadFailed' => 'Bild konnte nicht gelesen werden. Bitte erneut versuchen.',
			'common.groupAlbumPhotoUploaded' => 'Bild hochgeladen',
			'common.groupAlbumPhotoUploadFailed' => 'Bild-Upload fehlgeschlagen. Bitte später erneut versuchen.',
			'common.groupAlbumCreateTooltip' => 'Album erstellen',
			'common.groupAlbumPhotoBatchDeleteTitle' => 'Bilder löschen',
			'common.groupAlbumPhotoBatchDeleteConfirm' => ({required Object count}) => '${count} ausgewählte Bilder wirklich löschen?',
			'common.groupAlbumPhotoDeleteFailed' => 'Löschen fehlgeschlagen. Bitte später erneut versuchen.',
			'common.groupAlbumPhotoDeletedAll' => ({required Object count}) => '${count} Bilder gelöscht',
			'common.groupAlbumPhotoDeletedPartial' => ({required Object success, required Object fail}) => '${success} gelöscht, ${fail} fehlgeschlagen',
			'common.groupAlbumPhotoDeleteTitle' => 'Bild löschen',
			'common.groupAlbumPhotoDeleteConfirm' => 'Dieses Bild wirklich löschen?',
			'common.groupAlbumPhotoDeleted' => 'Bild gelöscht',
			'common.groupAlbumPhotoBatchDeleteTooltip' => 'Löschen',
			'common.groupAlbumPhotoExitSelection' => 'Auswahl verlassen',
			'common.groupAlbumPhotoOpenFailed' => 'Bildlink kann nicht geöffnet werden',
			'common.groupAlbumPhotoNotFound' => 'Bild existiert nicht oder wurde gelöscht',
			'common.groupAlbumPhotoOpenExternal' => 'In der App öffnen',
			'common.groupAlbumPhotoCoverUpdated' => 'Als Album-Cover festgelegt',
			'common.groupAlbumPhotoCoverFailed' => 'Cover konnte nicht festgelegt werden. Bitte später erneut versuchen.',
			'common.groupAlbumPhotoNext' => 'Weiter',
			'common.groupAlbumPhotoResolution' => 'Auflösung',
			'common.groupAlbumPhotoUploader' => 'Hochgeladen von',
			'common.sectionDisplay' => 'Anzeige',
			'common.sectionTheme' => 'Design',
			'common.selectLanguage' => 'Sprache wählen',
			'common.completionSuggestions' => 'Tipps:',
			'common.sectionGeneral' => 'Allgemein',
			'common.sectionPrivacySecurity' => 'Datenschutz & Sicherheit',
			'common.sectionHelpAbout' => 'Hilfe & Info',
			'common.msgOnlyVisibleToParties' => 'Nachricht nur für Absender und Empfänger lesbar',
			'common.msgNotEncrypted' => 'Nachricht unverschlüsselt',
			'common.unreadCount' => ({required Object count}) => '${count} ungelesen',
			'common.durationMinutes' => ({required Object count}) => '${count} Min.',
			'common.durationSeconds' => ({required Object count}) => '${count} Sek.',
			'common.rechargeAmountError' => 'Betrag zwischen 0.01 und 10000 Yuan eingeben',
			'common.rechargeSuccess' => 'Aufgeladen',
			'common.rechargeConfirm' => 'Aufladen bestätigen',
			'common.transactionHistory2' => 'Umsätze',
			'common.noTransactionHistory' => 'Keine Umsätze',
			'common.transactionTypeIncome' => 'Aufladung',
			'common.transactionTypeExpense' => 'Ausgabe',
			'common.sectionLoginCredentials' => 'Zugangsdaten',
			'common.channelInvitations' => 'Kanal-Einladungen',
			'common.acceptInvitationFailed' => 'Annehmen fehlgeschlagen',
			'common.rejectInvitationFailed' => 'Ablehnen fehlgeschlagen',
			'common.invitationAccepted' => 'Einladung angenommen',
			'common.invitationRejected' => 'Einladung abgelehnt',
			'common.invitationStatusPending' => 'Ausstehend',
			'common.invitationStatusAccepted' => 'Angenommen',
			'common.invitationStatusRejected' => 'Abgelehnt',
			'common.invitationStatusExpired' => 'Abgelaufen',
			'common.invitationStatusCancelled' => 'Abgesagt',
			'common.invitationStatusUnknown' => 'Unbekannt',
			'common.noReceivedInvitations' => 'Keine erhaltenen Einladungen',
			'common.noSentInvitations' => 'Keine gesendeten Einladungen',
			'common.processingDots' => 'Wird verarbeitet...',
			'common.purchaseFailed' => 'Kauf fehlgeschlagen. Bitte später erneut versuchen.',
			'common.purchaseSuccess' => 'Gekauft',
			'common.insufficientBalanceTitle' => 'Guthaben unzureichend',
			'common.insufficientBalanceContent' => ({required Object currency, required Object balance, required Object price}) => 'Aktuelles Guthaben: ${currency} ${balance}, benötigt: ${currency} ${price}. Bitte zuerst aufladen.',
			'common.goRecharge' => 'Aufladen',
			'common.noOrders' => 'Keine Bestellungen',
			'common.orderDetailLoadFailed' => 'Bestelldetails konnten nicht geladen werden',
			'common.orderNoLabel' => ({required Object no}) => 'Bestellnr.: ${no}',
			'common.orderStatusCancelled' => 'Abgesagt',
			'common.orderStatusUnknown' => 'Unbekannt',
			'common.fileOpenFailed' => 'Datei kann nicht geöffnet werden',
			'common.e2eeLocalBackup' => 'Lokales Backup',
			'common.e2eeLocalBackupDesc' => 'Verschlüsseltes Backup lokal oder in der Cloud speichern',
			'common.e2eeDeleteKey' => 'Schlüssel löschen',
			'common.e2eeDeleteKeyDesc' => 'Lokalen Schlüssel löschen (nicht wiederherstellbar)',
			'common.e2eeCurrentKeyInfo' => 'Aktueller Schlüssel',
			'common.e2eeE2EEEnabled' => 'E2EE aktiv',
			'common.e2eeNoKeyDetected' => 'Kein E2EE-Schlüssel gefunden',
			'common.e2eeNoKeyDesc' => 'Bitte Schlüsselpaar erstellen oder aus Backup wiederherstellen',
			'common.e2eeAboutTitle' => 'Über E2EE',
			'common.e2eeInfoPoint1' => '• Nachrichten werden vor dem Senden verschlüsselt, Server sehen keinen Inhalt',
			'common.e2eeInfoPoint2' => '• Nach Gerätewechsel oder Schlüssellöschung sind alte Nachrichten evtl. nicht entschlüsselbar',
			'common.e2eeInfoPoint3' => '• Schlüssel regelmäßig sichern, um Datenverlust zu vermeiden',
			'common.e2eeExportBackup' => 'Backup exportieren',
			'common.e2eeExportBackupDesc' => 'Verschlüsseltes Backup erstellen',
			'common.e2eeImportBackup' => 'Backup importieren',
			'common.e2eeImportBackupDesc' => 'Schlüssel aus Backup wiederherstellen',
			'common.e2eeGenerateKeyConfirm' => 'Neues E2EE-Schlüsselpaar erstellen?',
			'common.e2eeWarnOldMessagesLost' => '• Alte Nachrichten nicht mehr entschlüsselbar',
			'common.e2eeWarnNeedNewBackup' => '• Neues Backup erforderlich',
			'common.e2eeConfirmGenerate' => 'Erstellen',
			'common.aiPlaintextConfirmTitle' => 'Klartext-Chat mit KI-Assistent',
			'common.aiPlaintextConfirmBody' => 'Nachrichten und Anhänge in diesem Chat sind NICHT Ende-zu-Ende-verschlüsselt; der Server kann sie lesen.',
			'common.aiPlaintextConfirmNote' => 'Dieses Gerät merkt sich die Bestätigung und fragt erneut, wenn sich Identität oder Schlüssel des Gegenübers ändern.',
			'common.aiPlaintextConfirmOk' => 'Verstanden, senden',
			'common.aiPlaintextConfirmCancel' => 'Abbrechen',
			'common.e2eeDeleteKeyConfirm' => 'Aktuellen Schlüssel wirklich löschen?',
			'common.e2eeWarnCannotRestore' => '• Nach Löschen nicht wiederherstellbar',
			'common.e2eeWarnAllMsgsLost' => '• Alle E2EE-Nachrichten nicht mehr entschlüsselbar',
			'common.e2eeConfirmDelete' => 'Löschen',
			'common.e2eeKeyGeneratedSuccess' => 'Schlüssel erstellt',
			'common.e2eeDeviceIdInfo' => ({required Object id}) => 'Geräte-ID: ${id}',
			'common.e2eeKeyIdInfo' => ({required Object id}) => 'Schlüssel-ID: ${id}',
			'common.e2eeCreatedAtInfo' => ({required Object time}) => 'Erstellt am: ${time}',
			'common.e2eeImportantNote' => 'Wichtiger Hinweis',
			'common.e2eeWarnOldMayNotDecrypt' => '• Alte Nachrichten evtl. nicht entschlüsselbar',
			'common.e2eeSuggestBackupNow' => '• Backup jetzt empfohlen',
			'common.e2eeGoBackup' => 'Zum Backup',
			'common.e2eeKeyGenerateFailed' => 'Schlüsselerstellung fehlgeschlagen. Bitte erneut versuchen.',
			'common.e2eeKeyDeleted' => 'Schlüssel gelöscht',
			'common.e2eeDeleteFailed' => 'Löschen fehlgeschlagen. Bitte erneut versuchen.',
			'common.webFeatureNotification' => 'Desktop-Benachrichtigungen',
			'common.webFeatureNotificationDesc' => 'Neue Nachrichten auch bei inaktiver App',
			'common.webQRConfirmOnPhone' => 'Bitte am Handy bestätigen',
			'common.webQRLoginFailed' => 'Anmeldung fehlgeschlagen',
			'common.webQRLoginSuccess' => 'Angemeldet',
			'common.webQRExpiresIn' => ({required Object seconds}) => 'Läuft in ${seconds} Sek. ab',
			'common.webQRStatusFailed' => 'Anmeldung fehlgeschlagen. Bitte erneut versuchen.',
			'common.webQRStatusSuccess' => 'Weiterleitung...',
			'common.webLoginEmptyError' => 'Konto und Passwort eingeben',
			'common.webQRGenerateFailed' => 'QR-Code konnte nicht erstellt werden',
			'common.webQRTokenInvalid' => 'Anmelde-Token ungültig',
			'common.e2eeErrNoRecipientKey' => 'Geräteschlüssel des Empfängers nicht verfügbar, Nachricht nicht gesendet',
			'common.e2eeDecryptFailed' => 'Nachricht kann nicht entschlüsselt werden',
			'common.e2eeDecryptFailedReasons' => 'Nachricht nicht entschlüsselbar. Mögliche Ursachen:',
			'common.e2eeDecryptReasonOtherDevice' => '• Anmeldung auf anderem Gerät',
			'common.e2eeDecryptReasonKeyExpired' => '• Geräteschlüssel abgelaufen',
			'common.e2eeDecryptReasonDataCorrupt' => '• App-Daten beschädigt',
			'common.e2eeDecryptChooseSolution' => 'Lösung wählen:',
			'common.e2eeDecryptRecreateHint' => 'Hinweis: Nach der Neuerstellung muss die Gegenseite Ihren neuen Schlüssel abrufen; während der Änderung noch nicht zugestellte verschlüsselte Nachrichten werden möglicherweise nicht automatisch erneut gesendet. Der Nachrichtenverlauf ist nicht betroffen.',
			'common.e2eePeerKeyChanged' => 'Die Sicherheitsnummer dieses Kontakts hat sich geändert (möglicherweise wurde die App neu installiert oder das Gerät gewechselt). Wenn dir Sicherheit wichtig ist, überprüfe die Identität über einen anderen Kanal.',
			'common.e2eeDecryptActionRecreateKey' => 'Schlüssel neu erstellen (empfohlen)',
			'common.e2eeDecryptActionRelogin' => 'Neu anmelden',
			'common.e2eeDecryptActionRemindLater' => 'Später erinnern',
			'common.e2eeBackupExportTitle' => 'E2EE-Backup exportieren',
			'common.e2eeBackupPwdCantRecover' => '• Backup-Passwort nicht wiederherstellbar, gut aufbewahren!',
			'common.e2eeBackupStoreMultipleNote' => '• Backup an mehreren Orten speichern (E-Mail, Cloud, USB-Stick)',
			'common.e2eeBackupPwdLabel' => 'Backup-Passwort *',
			'common.e2eeBackupPwdHint' => 'Min. 12 Zeichen, Groß-/Kleinschreibung, Zahlen, Sonderzeichen',
			'common.e2eeBackupConfirmPwdLabel' => 'Passwort bestätigen *',
			'common.e2eeBackupConfirmPwdHint' => 'Passwort wiederholen',
			'common.e2eeBackupNoteLabel' => 'Notiz (optional)',
			'common.e2eeBackupNoteHint' => 'z. B. Hauptgerät-Backup - Jan 2026',
			'common.e2eeBackupPwdStrengthLabel' => 'Passwortstärke',
			'common.e2eeBackupPwdWeak' => 'Schwach',
			'common.e2eeBackupPwdMedium' => 'Mittel',
			'common.e2eeBackupPwdStrong' => 'Stark',
			'common.e2eeBackupPwdVeryStrong' => 'Sehr stark',
			'common.e2eeBackupGenerateBtn' => 'Backup erstellen',
			'common.e2eeBackupFileGenerated' => 'Backup erstellt!',
			'common.e2eeBackupShareBtn' => 'Per E-Mail/Cloud teilen',
			'common.e2eeBackupShareContent' => 'Mein Imboy E2EE-Schlüssel-Backup. Sicher aufbewahren, nicht weitergeben.',
			'common.e2eeBackupErrPwdMismatch' => 'Passwörter stimmen nicht überein',
			'common.e2eeBackupErrNoKeyData' => 'Schlüsseldaten nicht verfügbar',
			'common.e2eeBackupErrExportFailed' => 'Export fehlgeschlagen. Bitte erneut versuchen.',
			'common.e2eeBackupErrShareFailed' => 'Teilen fehlgeschlagen. Bitte erneut versuchen.',
			'common.e2eeBackupExportSuccessTitle' => 'Backup exportiert',
			'common.e2eeBackupExportSuccessBody' => 'E2EE-Backup wurde erstellt.',
			'common.e2eeBackupImportantNoteColon' => 'Wichtig:',
			'common.e2eeBackupKeepSafe' => '• Backup und Passwort sicher aufbewahren',
			'common.e2eeBackupStoreMultipleLoc' => '• An mehreren Orten speichern',
			'common.e2eeBackupPwdCantRecoverNote' => '• Passwort nicht wiederherstellbar',
			'common.e2eeBackupImportTitle' => 'E2EE-Backup importieren',
			'common.e2eeBackupImportGuide' => 'Hinweise',
			'common.e2eeBackupImportReplaceKey' => '• Aktueller Schlüssel wird beim Import ersetzt',
			'common.e2eeBackupImportTrustedSource' => '• Nur Backups aus vertrauenswürdiger Quelle',
			'common.e2eeBackupSelectFile' => 'Backup-Datei wählen',
			'common.e2eeBackupSelectFileHint' => 'Tippen, um Backup zu wählen (.enc)',
			'common.e2eeBackupInfoTitle' => 'Backup-Info',
			'common.e2eeBackupVersionLabel' => 'Version',
			'common.e2eeBackupAlgorithmLabel' => 'Algorithmus',
			'common.e2eeBackupFileSizeLabel' => 'Dateigröße',
			'common.e2eeBackupFileBytes' => ({required Object bytes}) => '${bytes} Bytes',
			'common.e2eeBackupGeneratedFile' => ({required Object name}) => 'Datei: ${name}',
			'common.e2eeBackupFileValid' => '✓ Format gültig',
			'common.e2eeBackupImportPwdHint' => 'Backup-Passwort eingeben',
			'common.e2eeBackupImportBtn' => 'Schlüssel importieren',
			'common.e2eeBackupErrSelectFile' => 'Dateiauswahl fehlgeschlagen. Bitte erneut versuchen.',
			'common.e2eeBackupErrValidateFailed' => 'Validierung fehlgeschlagen. Format prüfen.',
			'common.e2eeBackupErrImportFailed' => 'Import fehlgeschlagen. Passwort prüfen.',
			'common.e2eeBackupImportSuccessTitle' => 'Importiert',
			'common.e2eeBackupImportSuccessBody' => 'E2EE-Schlüssel wiederhergestellt!',
			'common.e2eeBackupImportSuccessNote' => 'Hinweis: Nur Gruppensitzungen, die in dieser Sicherung enthalten und erfolgreich gespeichert wurden, können den zugehörigen Verlauf entschlüsseln. Einzelchats sind nicht wiederherstellbar, da 1:1-Schlüssel nicht geräteübergreifend gesichert werden.',
			'common.e2eeBackupHistoryGrantTitle' => 'Historische Gruppenschlüssel wiederherstellen',
			'common.e2eeBackupHistoryGrantBody' => ({required Object count}) => 'Dies autorisiert dieses Gerät separat, ${count} Gruppenschlüssel wiederherzustellen und Verlauf nur innerhalb der jeweiligen Mitgliedschaftsgeneration und Nachrichtensequenz zu entschlüsseln. Identitätsschlüssel wurden bereits wiederhergestellt; Abbrechen überspringt diese Gruppenschlüssel.',
			'common.e2eeBackupHistoryRestoreResult' => ({required Object restored, required Object omitted}) => 'Historische Gruppenschlüssel: ${restored} autorisiert und wiederhergestellt, ${omitted} ausgelassen',
			'common.e2eeBackupErrAccountMismatch' => 'Dieses Backup gehört zu einem anderen Konto; Wiederherstellung abgelehnt',
			'common.e2eeBackupErrStaleBackup' => 'Dieses Backup ist älter als die zuletzt erfolgreiche Wiederherstellung auf diesem Gerät (möglicher Replay); abgelehnt',
			'common.e2eeBackupRestorePartialTitle' => 'Teilweise abgeschlossen',
			'common.e2eeBackupRestorePartialBody' => ({required Object written, required Object total}) => 'E2EE-Schlüssel wiederhergestellt; das Schreiben der Gruppenschlüssel wurde unterbrochen (${written}/${total} Einträge). Dieselbe Backup-Datei erneut importieren, um fortzufahren — wiederholtes Schreiben ist sicher',
			'common.e2eeBackupSafetyNumberChangedNote' => 'Der Identitätsschlüssel dieses Geräts hat sich geändert, daher ändern sich die Sicherheitsnummern mit deinen Kontakten. Bitte erneut verifizieren',
			'common.e2eeBackupCreatedAtRow' => 'Erstellt am',
			'common.e2eeBackupCloudUploadBtn' => 'In die Cloud sichern',
			'common.e2eeBackupCloudUploadSuccess' => ({required Object version}) => 'In der Cloud gesichert (Version ${version})',
			'common.e2eeBackupErrCloudUploadFailed' => 'Cloud-Backup fehlgeschlagen, bitte erneut versuchen',
			'common.e2eeBackupCloudRestoreTitle' => 'Aus Cloud-Backup wiederherstellen',
			'common.e2eeBackupCloudRestoreHint' => ({required Object version}) => 'Cloud-Backup erkannt (Version ${version})',
			'common.e2eeBackupCloudRestoreBtn' => 'Aus der Cloud wiederherstellen',
			'common.e2eeBackupCloudRestoreConfirmNote' => 'Die Wiederherstellung überschreibt die aktuellen E2EE-Schlüssel auf diesem Gerät',
			'common.e2eeBackupCloudPwdHint' => 'Backup-Passphrase eingeben',
			'common.e2eeBackupErrNoCloudBackup' => 'Kein Cloud-Backup vorhanden',
			'common.e2eeBackupErrCloudPwd' => 'Falsche Passphrase oder beschädigtes Backup',
			'common.e2eeBackupErrCloudRestoreFailed' => 'Cloud-Wiederherstellung fehlgeschlagen, bitte erneut versuchen',
			'common.e2eeBackupUrlImportTitle' => 'Oder über einen Link importieren',
			'common.e2eeBackupUrlImportHint' => 'Fügen Sie die URL der Backupdatei ein (nur HTTPS); sie wird automatisch heruntergeladen und verifiziert',
			'common.e2eeBackupUrlFieldLabel' => 'URL der Backupdatei',
			'common.e2eeBackupUrlFieldHint' => 'https://...',
			'common.e2eeBackupUrlImportBtn' => 'Herunterladen und verifizieren',
			'common.e2eeBackupUrlDownloading' => 'Wird heruntergeladen…',
			'common.e2eeBackupErrUrlInvalid' => 'Ungültige URL, nur HTTPS',
			'common.e2eeBackupErrUrlDownload' => 'Download fehlgeschlagen, bitte URL und Netzwerk prüfen',
			'common.e2eeBackupErrUrlTimeout' => 'Download-Zeitüberschreitung, bitte erneut versuchen',
			'common.e2eeBackupErrUrlTls' => 'Sichere Verbindung fehlgeschlagen, Serverzertifikat konnte nicht verifiziert werden',
			'common.e2eeBackupErrUrlHttp' => 'Server hat einen Fehler zurückgegeben',
			'common.e2eeBackupErrUrlEmpty' => 'Server hat leeren Inhalt zurückgegeben',
			'common.e2eeBackupErrUrlTooLarge' => 'Datei zu groß (10MB-Limit überschritten)',
			'common.passwordEncryptFailed' => 'Passwort-Verschlüsselung fehlgeschlagen',
			'common.initConfigTimeout' => 'Zeitüberschreitung: Netzwerk oder Server prüfen',
			'common.initConfigNetworkError' => ({required Object code}) => 'Netzwerk- oder Serverfehler (HTTP ${code})',
			'common.initConfigProtocolError' => 'Server-Protokoll fehlerhaft',
			'common.initConfigFetchFailed' => 'Konfiguration konnte nicht geladen werden. Netzwerk prüfen.',
			'common.saveFailedRetry' => 'Speichern fehlgeschlagen. Bitte erneut versuchen.',
			'common.downloadFileNotFound' => 'Download-Datei nicht vorhanden. Bitte erneut versuchen.',
			'common.downloadHashRetrying' => ({required Object retry, required Object max}) => 'Prüfung fehlgeschlagen, erneut laden (${retry}/${max})',
			'common.downloadHashFailed' => 'Mehrfachprüfung fehlgeschlagen. Netzwerk prüfen.',
			'common.buttonBackHome' => 'Zum Start',
			'common.featureNotEnabled' => 'Funktion nicht verfügbar',
			'common.featureDisabledName' => ({required Object name}) => '${name}-Funktion nicht verfügbar',
			'common.imageLoadFailed' => 'Laden fehlgeschlagen',
			'common.loadFailedWithError' => ({required Object error}) => 'Laden fehlgeschlagen: ${error}',
			'common.webAudioNotSupported' => 'Sprachnachrichten im Web nicht unterstützt',
			'common.e2eeKeyRecreationFailed' => ({required Object error}) => 'Fehler: ${error}',
			'common.redPacket' => 'Geschenk',
			'common.transfer' => 'Überweisung',
			'common.withdraw' => 'Auszahlung',
			'common.redPacketSend' => 'Geschenk senden',
			'common.redPacketDetail' => 'Geschenk-Details',
			'common.transferSend' => 'Überweisung starten',
			'common.greetingDefault' => 'Frohes neues Jahr',
			'common.transferAmountYuan' => ({required Object amount}) => 'Überwiesen: ${amount} Yuan',
			'common.insufficientBalance' => 'Guthaben unzureichend',
			'common.withdrawSuccess' => 'Auszahlung erfolgreich',
			'common.withdrawConfirm' => 'Auszahlung bestätigen',
			'common.withdrawFeeNotice' => 'Gebühren und Gutschriftsdauer richten sich nach der tatsächlichen Abrechnung',
			'common.withdrawAmountError' => 'Mindestens 0.01 Yuan eingeben',
			'common.withdrawAccountEmpty' => 'Auszahlungskonto eingeben',
			'common.withdrawMethod' => 'Auszahlungsmethode',
			'common.withdrawAmountLabel' => 'Auszahlungsbetrag',
			'common.withdrawAlipay' => 'Alipay',
			'common.withdrawWechat' => 'WeChat',
			'common.walletBalanceLabel' => ({required Object balance}) => 'Guthaben ￥${balance}',
			'common.withdrawAccountHintAlipay' => 'Auszahlungskonto (E-Mail oder Telefonnummer)',
			'common.withdrawAccountHintWechat' => 'Auszahlungskonto (WeChat-ID)',
			'common.withdrawAlipayFormatError' => 'Bitte eine gültige Alipay-E-Mail-Adresse oder Telefonnummer eingeben',
			'common.withdrawWechatFormatError' => 'Bitte eine gültige WeChat-ID eingeben (6-20 Zeichen, beginnend mit einem Buchstaben)',
			'common.withdrawConfirmAmount' => ({required Object amount}) => 'Auszahlungsbetrag: ￥${amount}',
			'common.withdrawConfirmMethod' => ({required Object method}) => 'Auszahlungsmethode: ${method}',
			'common.withdrawConfirmAccount' => ({required Object account}) => 'Auszahlungskonto: ${account}',
			'common.showPassword' => 'Passwort anzeigen',
			'common.hidePassword' => 'Passwort ausblenden',
			'common.turnOnFlashlight' => 'Taschenlampe einschalten',
			'common.turnOffFlashlight' => 'Taschenlampe ausschalten',
			'common.pauseScan' => 'Scan pausieren',
			'common.resumeScan' => 'Scan fortsetzen',
			'common.enterFullscreen' => 'Vollbild aktivieren',
			'common.exitFullscreen' => 'Vollbild beenden',
			'common.developer' => 'Entwickler',
			'common.fontSizeOptionSmall' => 'Klein',
			'common.fontSizeOptionNormal' => 'Standard',
			'common.fontSizeOptionMedium' => 'Mittel',
			'common.fontSizeOptionLarge' => 'Groß',
			'common.fontSizeOptionExtraLarge' => 'Sehr groß',
			'common.fontSizeOptionHuge' => 'Riesig',
			'common.searchFailedRetry' => 'Suche fehlgeschlagen, bitte erneut versuchen',
			'common.searchDisabledTitle' => 'Nachrichtensuche nicht verfügbar',
			'common.searchDisabledByEncryption' => 'Ende-zu-Ende-Verschlüsselung ist aktiv; der Server kann die Nachrichten nicht lesen, daher gibt es keine Volltextsuche',
			'common.collectedVideoFormatIncorrectCannotFindVideoUri' => 'Videoformat nicht unterstützt, Video-URI nicht auffindbar',
			'common.justNow' => 'Gerade eben',
			'common.minutesAgo' => 'Min.',
			'common.hoursAgo' => 'Std.',
			'common.me' => 'Ich',
			'common.minimize' => 'Minimieren',
			'common.collapse' => 'Einklappen',
			'common.expandFull' => 'Ausklappen',
			'common.noHistory' => 'Kein Verlauf',
			'common.noNewRegisteredUsersTitle' => 'Keine neuen registrierten Nutzer',
			'common.answer' => 'Annehmen',
			'common.declineCall' => 'Ablehnen',
			'common.switchCamera' => 'Kamera wechseln',
			'common.reconnecting' => 'Schlechte Verbindung, wird neu verbunden…',
			'common.amountMustPositive' => 'Betrag muss größer als 0 sein',
			'common.enterAmount' => 'Bitte Betrag eingeben',
			'common.f2fEnteringGroup' => ({required Object count}) => '${count} Personen treten gleich dem Gruppenchat bei',
			'common.f2fSecretCode' => 'Geheimcode',
			'common.uploadPartialFailed' => ({required Object count}) => '${count} Uploads fehlgeschlagen',
			'common.momentsHasFailedUploads' => 'Einige Medien wurden nicht hochgeladen. Bitte erneut versuchen oder entfernen und dann veröffentlichen',
			'common.payReceiveSuccess' => 'Zahlung empfangen!',
			'common.purchaseConfirming' => 'Zahlung wird bestätigt. Bitte später den Bestellstatus prüfen',
			'common.timeNowShort' => 'jetzt',
			'common.timeMinutesShort' => ({required Object count}) => '${count} Min.',
			'common.timeHoursShort' => ({required Object count}) => '${count} Std.',
			'common.timeDaysShort' => ({required Object count}) => '${count} T',
			'common.transferAccepted' => 'Empfangen',
			'common.transferAmountLabel' => 'Überweisungsbetrag',
			'common.transferConfirm' => 'Überweisung bestätigen',
			'common.transferDefaultRemark' => 'Überweisung an Freund',
			'common.transferMinAmountError' => 'Mindestbetrag für Überweisungen: 0.01 Yuan',
			'common.transferPending' => 'Warten auf Bestätigung der Gegenseite',
			'common.transferReceiving' => 'Zahlung wird empfangen...',
			'common.transferRefunded' => 'Zurücküberwiesen',
			'common.transferRemarkLabel' => 'Überweisungsnotiz',
			'common.transferTapToReceive' => 'Zum Empfangen tippen',
			'common.voiceSttConverting' => 'Wird erkannt...',
			'common.voiceSttNotConfigured' => 'Sprache-zu-Text ist noch nicht konfiguriert',
			'common.voiceSttPreviewTitle' => 'Sprache-zu-Text-Vorschau',
			'common.redPacketAmountTooSmall' => 'Gesamtbetrag mindestens Anzahl × 0.01 Yuan',
			'common.redPacketBrand' => 'IMBoy-Geschenk',
			'common.redPacketCount' => 'Anzahl Geschenke',
			'common.redPacketCountEmpty' => 'Bitte Anzahl der Geschenke eingeben',
			'common.redPacketCountMin' => 'Anzahl muss mindestens 1 sein',
			'common.redPacketCountUnit' => 'Stk.',
			'common.redPacketCurrentLucky' => 'Aktuell: Zufallsbetrag',
			'common.redPacketCurrentNormal' => 'Aktuell: Festbetrag',
			'common.redPacketDialogSubtitle' => 'Viel Glück und großen Reichtum',
			'common.redPacketDialogTitle' => 'Ein Geschenk für Sie',
			'common.redPacketFetchError' => 'Fehler beim Laden der Geschenk-Details',
			'common.redPacketFetchFailed' => 'Geschenk-Details konnten nicht geladen werden',
			'common.redPacketGreetingLabel' => 'Nachricht / Glückwünsche',
			'common.redPacketNotFound' => 'Geschenk nicht gefunden oder bereits gelöscht',
			'common.redPacketReceiverLabel' => ({required Object uid}) => 'Nutzer: ${uid}',
			'common.redPacketSingleAmount' => 'Einzelnbetrag',
			'common.redPacketStuffLucky' => 'Zufallsbeträge verteilen',
			'common.redPacketStuffNormal' => 'Festbetrag senden',
			'common.redPacketSwitchToLucky' => 'Zu Zufallsbetrag wechseln',
			'common.redPacketSwitchToNormal' => 'Zu Festbetrag wechseln',
			'common.redPacketTotalAmount' => 'Gesamtbetrag',
			'common.redPacketView' => 'Geschenk ansehen',
			'common.e2eeErrPeerNotOnboarded' => 'Die Gegenseite war noch auf keinem Gerät angemeldet, verschlüsseltes Senden derzeit nicht möglich. Bitte warten Sie, bis sich die Gegenseite angemeldet hat, und versuchen Sie es erneut',
			'common.e2eeRecoveryKeyTitle' => 'Wiederherstellungsschlüssel',
			'common.e2eeRecoveryKeyCopiedAutoClear' => ({required Object seconds}) => 'Wiederherstellungsschlüssel kopiert. Die Zwischenablage wird in ${seconds} Sek. automatisch geleert. Bitte schnellstmöglich sichern',
			'common.e2eeErrAttachmentSeal' => 'Versiegeln der verschlüsselten Datei fehlgeschlagen, die Datei wurde nicht hochgeladen. Bitte später erneut versuchen',
			'common.e2eeErrForwardPlaintextTarget' => 'Der Ziel-Chat ist nicht Ende-zu-Ende-verschlüsselt; die verschlüsselte Datei kann nicht weitergeleitet werden',
			'common.e2eeErrForwardUndecryptable' => 'Die ursprüngliche verschlüsselte Datei kann auf diesem Gerät nicht entschlüsselt werden; Weiterleitung fehlgeschlagen',
			'common.e2eeRetryFailedMessages' => 'Nachrichten mit Entschlüsselungsfehler erneut versuchen',
			'common.e2eeRetryFailedDone' => ({required Object count}) => '${count} Nachrichten mit Entschlüsselungsfehler erneut versucht',
			'common.e2eeRetryFailedNone' => 'Keine Nachrichten zum Wiederholen',
			'common.e2eeModeStandard' => 'Standardmodus',
			'common.e2eeModeCompliance' => 'Compliance-Verschlüsselung',
			'common.e2eeModeStrict' => 'Ende-zu-Ende-Verschlüsselung',
			'common.e2eeRecoveryKeySaveNote' => 'Bitte sichern Sie diesen Wiederherstellungsschlüssel sofort (Screenshot oder Passwort-Manager). Bei vergessener Passphrase ist er der einzige Schlüssel zum Entschlüsseln des Backups; geht er verloren, ist das Backup dauerhaft nicht wiederherstellbar.',
			'common.e2eeUseRecoveryKey' => 'Wiederherstellungsschlüssel erstellen (Ersatz-Zugang bei vergessener Passphrase)',
			'common.complianceKeyChangedTitle' => 'Compliance-Audit-Schlüssel hat sich geändert',
			'common.complianceKeyChangedBody' => 'Der vom Server bereitgestellte öffentliche Compliance-Schlüssel stimmt nicht mit dem lokal gepinnten Wert überein. Handelt es sich um eine beabsichtigte Schlüsselrotation durch den Administrator, tippen Sie auf „Rotation bestätigen“; andernfalls senden Sie keine weiteren verschlüsselten Nachrichten und kontaktieren Sie den Administrator zur Prüfung.',
			'common.complianceKeyChangedActionConfirm' => 'Rotation bestätigen',
			'common.complianceKeyChangedActionKeep' => 'Vorerst nicht bestätigen',
			'common.initConfigDecryptFailed' => 'Konfiguration konnte nicht entschlüsselt werden: Sicherheitsschlüssel von App und Server stimmen nicht überein. Bitte App aktualisieren oder Administrator kontaktieren',
			'common.retry' => 'Wiederholen',
			'common.retrying' => 'Wiederholung…',
			'complaint.complaint' => 'Beschwerde',
			'complaint.e2eeConsentTitle' => 'Verschlüsselte Beweise einreichen',
			'complaint.e2eeConsentBody' => 'Diese Nachricht ist Ende-zu-Ende-verschlüsselt; der Server kann ihren Inhalt nicht einsehen. Durch das Einreichen eines Auszugs wird der ausgewählte Klartext den Moderatoren zur Prüfung offengelegt. Stimmen Sie zu?',
			'complaint.e2eeConsentSubmit' => 'Zustimmen und einreichen',
			'complaint.e2eeConsentDecline' => 'Nur melden (ohne Inhalt)',
			'complaintReason.spam' => 'Spam',
			'complaintReason.harassment' => 'Belästigung',
			'complaintReason.inappropriate' => 'Unangemessener Inhalt',
			'complaintReason.other' => 'Sonstiges',
			'contact.blocked' => 'Blockiert',
			'contact.applyChanges' => 'Bitte starten Sie die App neu, um die Änderungen zu übernehmen',
			'contact.inputNewTag' => 'Neuen Tag eingeben...',
			'contact.denylist' => 'Sperrliste',
			'contact.denylistEmpty' => 'Sperrliste ist leer',
			'contact.favoriteGroupTagsEtc' => 'Favoriten, Namen, Gruppen, Tags usw.',
			'contact.newFriend' => 'Neue Freunde',
			'contact.recommendToFriend' => 'Freunden empfehlen',
			'contact.remark' => 'Bemerkung',
			'contact.remarksTags' => 'Bemerkungen und Tags',
			'contact.selectAGroup' => 'Eine Gruppe auswählen',
			'contact.selectFriends' => 'Freunde auswählen',
			_ => null,
		} ?? switch (path) {
			'contact.tags' => 'Tags',
			'contact.suggestedTags' => 'Vorgeschlagene Tags',
			'contact.pleaseEnterRemark' => 'Bitte Bemerkung eingeben',
			'contact.enterRemark' => 'Bemerkung eingeben',
			'contact.pleaseEnterTags' => 'Bitte Tags eingeben',
			'contact.momentsVisibilityFriends' => 'Nur Freunde',
			'contact.tagLengthExceeded' => ({required Object param}) => 'Tag-Länge darf ${param} Zeichen nicht überschreiten',
			'contact.maxTagsExceeded' => ({required Object param}) => 'Maximal ${param} Tags erlaubt',
			'contact.selectedTags' => ({required Object param, required Object max}) => 'Ausgewählte Tags (${param}/${max})',
			'contact.friendRequestSent' => 'Gesendet',
			'contact.channelMaxTagsCount' => 'Max. 8 Tags',
			'contact.tagInputHint' => 'Tag eingeben...',
			'discovery.findNearbyPeople' => 'Personen in der Nähe finden',
			'discovery.moment' => 'Momente',
			'discovery.nearbyPeopleExplain' => 'Benutzer in Ihrer Nähe können Ihr Profil sehen und Ihnen Nachrichten senden. Finden Sie neue Freunde oder beenden Sie das Teilen jederzeit.\nIhre Telefonnummer bleibt verborgen.',
			'discovery.peopleNearby' => 'Personen in der Nähe',
			'discovery.scanResult' => 'Scan-Ergebnis',
			'discovery.myChannels' => 'Meine Kanäle',
			'discovery.otherUsersCanFindMe' => 'Andere Benutzer können mich durch Suche finden',
			'discovery.momentsDenyUidsLabel' => 'Ausgeschlossen UIDs (kommagetrennt)',
			'discovery.moments' => 'Momente',
			'discovery.momentsWriteComment' => 'Kommentar schreiben...',
			'discovery.momentsVisibility' => 'Sichtbarkeit',
			'discovery.momentsVisibilityPublic' => 'Öffentlich',
			'discovery.momentsVisibilityPartial' => 'Teilweise',
			'discovery.momentsVisibilityExclude' => 'Ausnahmen',
			'discovery.momentsDraftRestored' => 'Letzter Entwurf wiederhergestellt',
			'discovery.momentsFeedStale' => 'Netzwerkfehler, zwischengespeicherte Inhalte werden angezeigt',
			'discovery.momentActionLike' => 'Gefällt mir',
			'discovery.momentActionCancelLike' => 'Gefällt mir nicht mehr',
			'discovery.momentActionComment' => 'Kommentieren',
			'discovery.momentActionDelete' => 'Löschen',
			'discovery.momentActionReport' => 'Melden',
			'discovery.momentActionCancel' => 'Abbrechen',
			'discovery.momentLikedBy' => ({required Object names}) => '${names} gefällt das',
			'discovery.momentAndOthersLiked' => ({required Object names, required Object count}) => '${names} und ${count} weiteren gefällt das',
			'discovery.momentLikesCountOnly' => ({required Object count}) => '${count} Personen gefiel dies',
			'discovery.momentContentPlaceholder' => 'Woran denken Sie...',
			'discovery.momentShowFull' => 'Vollständig anzeigen',
			'discovery.momentCollapse' => 'Einklappen',
			'discovery.momentsDraftKeepTitle' => 'Entwurf behalten?',
			'discovery.momentsDraftKeepMessage' => 'Beim nächsten Mal weiterbearbeiten',
			'discovery.momentsDraftDiscard' => 'Verwerfen',
			'discovery.momentsDraftKeep' => 'Behalten',
			'discovery.openChannel' => 'Kanal öffnen',
			'discovery.paidChannelLocked' => 'Inhalt gesperrt (Kostenpflichtig)',
			'discovery.webQRScanned' => 'Gescannt',
			'discovery.momentActionMore' => 'Weitere Aktionen',
			'discovery.momentAtCount' => ({required Object count}) => '${count} Personen',
			'discovery.momentAtReminded' => ({required Object name}) => 'Benachrichtigt: ${name}',
			'discovery.momentAtRemindedMore' => ({required Object name, required Object count}) => 'Benachrichtigt: ${name} und ${count} weitere',
			'discovery.momentAtWho' => 'Wen benachrichtigen?',
			'discovery.momentLocation' => 'Standort',
			'discovery.momentLocationNone' => 'Standort nicht anzeigen',
			'enterpriseApp.title' => 'Unternehmens-App',
			'enterpriseApp.badgeAppDelegated' => 'Von App gesendet',
			'enterpriseApp.badgeHumanDelegated' => 'Mensch über App',
			'enterpriseApp.originTitle' => 'Nachrichtenherkunft',
			'enterpriseApp.originSenderApplication' => 'Von der Anwendung gesendet (Application)',
			'enterpriseApp.originSenderHuman' => 'Im Auftrag eines Menschen gesendet (Human sender)',
			'enterpriseApp.originApplicationId' => ({required Object id}) => 'Quell-Anwendung ${id}',
			'enterpriseApp.originHosted' => 'Unternehmensgehostet (kein privater Chat)',
			'enterpriseApp.originLabelSender' => 'Absenderherkunft',
			'enterpriseApp.originLabelEncryption' => 'Verschlüsselung',
			'enterpriseApp.originNonE2ee' => 'Nicht Ende-zu-Ende verschlüsselt',
			'enterpriseApp.originE2ee' => 'Ende-zu-Ende verschlüsselt (Mensch direkt)',
			'enterpriseApp.originMismatchTitle' => 'Widersprüchliche Herkunft',
			'enterpriseApp.originMismatchHint' => 'Diese Nachricht trägt sowohl eine Unternehmens-Anwendungsherkunft als auch eine Ende-zu-Ende-verschlüsselte Nutzlast. Sie wird als unverschlüsselte unternehmensgehostete Nachricht angezeigt, nicht als direkt gesendete verschlüsselte Nachricht eines Menschen.',
			'enterpriseApp.originUnrecognized' => 'Herkunftsmarkierung nicht erkannt; unverschlüsselt angezeigt',
			'enterpriseApp.actionDetails' => 'Details',
			'enterpriseApp.groupTitle' => 'Unternehmensgruppe',
			'enterpriseApp.groupArchivedBadge' => 'Archiviert',
			'enterpriseApp.groupActionArchive' => 'Archivieren',
			'enterpriseApp.groupArchiveTitle' => 'Unternehmensgruppe archivieren',
			'enterpriseApp.groupArchiveHint' => 'Archivieren ist einseitig: Die Gruppe wird für alle Unternehmens-Endpunkte unsichtbar und kann nicht wiederhergestellt werden.',
			'enterpriseApp.groupActionRename' => 'Gruppenname ändern',
			'enterpriseApp.groupRenameHint' => 'Neuer Gruppenname',
			'enterpriseApp.groupMembersTitle' => 'Mitglieder und Rollen',
			'enterpriseApp.groupRoleMember' => 'Mitglied',
			'enterpriseApp.groupRoleGuest' => 'Gast',
			'enterpriseApp.groupRoleAdmin' => 'Administrator',
			'enterpriseApp.groupRoleOwner' => 'Eigentümer',
			'enterpriseApp.groupRoleViceOwner' => 'Stellvertreter',
			'enterpriseApp.groupRoleOwnerLocked' => 'Die Eigentümerrolle kann nicht geändert oder von einer Anwendung vergeben werden',
			'enterpriseApp.groupOverLimit' => 'Mitgliederzahl überschreitet das Seitenlimit; Laden gestoppt',
			'enterpriseApp.groupEmpty' => 'Keine Unternehmensgruppen',
			'enterpriseApp.directoryTitle' => 'Mitgliedersuche',
			'enterpriseApp.directoryHint' => 'Nach Name oder Personalnummer suchen',
			'enterpriseApp.directoryEmpty' => 'Keine passenden Mitglieder',
			'enterpriseApp.directoryBounded' => 'Eingeschränktes Verzeichnis: nur seitenweise, kein Vollexport',
			'enterpriseApp.directoryLoadMore' => 'Mehr laden',
			'enterpriseApp.directoryEnd' => 'Ende der Liste',
			'enterpriseApp.retentionTitle' => 'Anhang-Aufbewahrung',
			'enterpriseApp.retentionUntil' => ({required Object time}) => 'Aufbewahrt bis ${time}',
			'enterpriseApp.holdNone' => 'Nicht gesperrt',
			'enterpriseApp.holdHeld' => 'Gesperrt',
			'enterpriseApp.holdReason' => ({required Object reason}) => 'Sperrgrund: ${reason}',
			'enterpriseApp.purgeLive' => 'Nicht gelöscht',
			'enterpriseApp.purgePurged' => 'Gelöscht',
			'enterpriseApp.retentionNoDelete' => 'Governance-Datensätze können nicht gelöscht werden',
			'enterpriseApp.retentionExtendOnly' => 'Aufbewahrung kann nur verlängert, nie verkürzt werden',
			'enterpriseApp.purgeBlockedHold' => 'Eine Sperre ist aktiv; Löschen blockiert',
			'enterpriseApp.purgeBlockedRetention' => 'Aufbewahrungsfrist läuft noch; Löschen blockiert',
			'enterpriseApp.purgeBlockedPurged' => 'Bereits gelöscht; nicht umkehrbar',
			'enterpriseApp.actionRetry' => 'Erneut versuchen',
			'enterpriseApp.actionSignIn' => 'Erneut anmelden',
			'enterpriseApp.error400Title' => 'Anfrage abgelehnt',
			'enterpriseApp.error400Hint' => 'Der übermittelte Inhalt ist nicht zulässig. Bitte prüfen und erneut versuchen.',
			'enterpriseApp.error401Title' => 'Anmeldung abgelaufen',
			'enterpriseApp.error401Hint' => 'Bitte erneut anmelden und wiederholen.',
			'enterpriseApp.error403Title' => 'Anwendung deaktiviert',
			'enterpriseApp.error403Hint' => 'Diese Anwendung oder ihre Organisation ist deaktiviert. Wenden Sie sich an Ihre Administration.',
			'enterpriseApp.error403ScopeTitle' => 'Unzureichender Berechtigungsumfang',
			'enterpriseApp.error403ScopeHint' => 'Dem aktuellen Zugangsnachweis fehlt der für diesen Vorgang nötige Umfang.',
			'enterpriseApp.error403BoundaryTitle' => 'Außerhalb der Unternehmensgrenze',
			'enterpriseApp.error403BoundaryHint' => 'Diese Ressource gehört nicht zum Unternehmen oder Workspace der aktuellen Anwendung.',
			'enterpriseApp.error404Title' => 'Ressource nicht gefunden',
			'enterpriseApp.error404Hint' => 'Die Ressource existiert nicht oder liegt außerhalb Ihres erreichbaren Unternehmensbereichs.',
			'enterpriseApp.error409Title' => 'Vorgangskonflikt',
			'enterpriseApp.error409Hint' => 'Doppelte Übermittlung oder der Zustand hat sich geändert. Aktualisieren und erneut versuchen.',
			'enterpriseApp.error422IdentityTitle' => 'Identität nicht zugeordnet',
			'enterpriseApp.error422IdentityHint' => 'Für dieses Mitglied ist noch keine externe Unternehmensidentität hinterlegt. Bitte zuerst zuordnen.',
			'enterpriseApp.error429Title' => 'Zu viele Anfragen',
			'enterpriseApp.error429Hint' => 'Das Unternehmens-Ratenlimit wurde erreicht. Bitte später erneut versuchen.',
			'enterpriseApp.error500Title' => 'Interner Dienstfehler',
			'enterpriseApp.error500Hint' => 'Der Dienst ist vorübergehend gestört. Bitte später erneut versuchen.',
			'enterpriseApp.error503Title' => 'Dienst nicht verfügbar',
			'enterpriseApp.error503Hint' => 'Das Unternehmens-Sicherheitsgate ist geschlossen. Bitte später erneut versuchen.',
			'enterpriseApp.errorUnboundTitle' => 'Dieser Build hat keinen Unternehmenskanal',
			'enterpriseApp.errorUnboundHint' => 'Unternehmens-Governance-Endpunkte benötigen einen Anwendungsnachweis, der nie im Client eingebettet wird. Bitte den Betreiber einen Kanal anbinden lassen.',
			'enterpriseApp.errorNetworkTitle' => 'Netzwerk nicht verfügbar',
			'enterpriseApp.errorNetworkHint' => 'Bitte Verbindung prüfen und erneut versuchen.',
			'enterpriseApp.errorUnknownTitle' => 'Unbekanntes Ergebnis',
			'enterpriseApp.errorUnknownHint' => 'Der Dienst hat ein unbekanntes Ergebnis geliefert. Bitte später erneut versuchen.',
			'enterpriseOa.title' => 'OA',
			'enterpriseOa.statusLoading' => 'Verbindung zum Unternehmens-Arbeitsbereich…',
			'enterpriseOa.statusErrorTitle' => 'OA kann nicht geladen werden',
			'enterpriseOa.statusErrorHint' => 'Netzwerkfehler oder Dienst vorübergehend nicht verfügbar. Bitte später erneut versuchen.',
			'enterpriseOa.statusExpiredTitle' => 'Anmeldung abgelaufen',
			'enterpriseOa.statusExpiredHint' => 'Der OA-Single-Sign-on-Code ist abgelaufen oder wurde bereits verwendet. Bitte erneut anmelden.',
			'enterpriseOa.statusLoggedOutTitle' => 'Von OA abgemeldet',
			'enterpriseOa.statusLoggedOutHint' => 'Die OA-Sitzung wurde beendet. Eine erneute Single-Sign-on-Anmeldung ist erforderlich.',
			'enterpriseOa.statusMismatchTitle' => 'Navigation aus dem Unternehmens-OA blockiert',
			'enterpriseOa.statusMismatchHint' => 'Es wurde eine nicht autorisierte Adresse erkannt. Das Laden wurde zum Schutz Ihres Kontos gestoppt.',
			'enterpriseOa.statusMismatchBlockedHost' => ({required Object host}) => 'Blockiert: ${host}',
			'enterpriseOa.statusOa401Title' => 'OA-Sitzung nicht autorisiert',
			'enterpriseOa.statusOa401Hint' => 'Der OA-Dienst hat „nicht autorisiert“ zurückgegeben. Bitte erneut anmelden.',
			'enterpriseOa.actionRetry' => 'Erneut versuchen',
			'enterpriseOa.actionRestartSso' => 'Erneut anmelden',
			'enterpriseOa.webviewSlotHint' => 'OA-Seitencontainer (Integration in W3)',
			'enterpriseOa.badgeDelegated' => 'Über OA',
			'enterpriseOa.markerNoE2ee' => 'Unternehmensverwaltet · nicht Ende-zu-Ende-verschlüsselt',
			'enterpriseOa.senderVia' => ({required Object origin}) => 'gesendet über ${origin}',
			'enterpriseOa.ssoIssuing' => 'SSO-Code wird angefordert…',
			'enterpriseOa.ssoCountdown' => ({required Object seconds}) => 'Code ist ${seconds} Sekunden gültig. Bitte bald anmelden.',
			'enterpriseOa.workbenchTitle' => 'Arbeitsbereich',
			'enterpriseOa.inboundTitle' => 'Anmeldung mit OA-Identität',
			'enterpriseOa.startInbound' => 'Identität mit OA bestätigen',
			'enterpriseOa.accountChoice' => 'Verknüpfen Sie ein bestehendes IMBoy-Konto oder erstellen Sie ausdrücklich ein neues.',
			'enterpriseOa.confirmLink' => 'Verknüpfung dieses Kontos bestätigen',
			'enterpriseOa.useExistingAccount' => 'Bei bestehendem IMBoy-Konto anmelden',
			'enterpriseOa.confirmCreate' => 'Erstellung eines neuen IMBoy-Kontos bestätigen',
			'enterpriseOa.apps' => 'Apps',
			'error.restartRequired' => 'App-Neustart erforderlich',
			'error.pleaseCheckNetwork' => 'Bitte überprüfen Sie Ihre Netzwerkeinstellungen.',
			'error.networkTroubleshootingStep1' => '1. Telefoneinstellungen öffnen, WLAN eingeschaltet lassen.',
			'error.networkTroubleshootingStep2' => '2. Einstellungen - Allgemein - Mobilfunkdaten, Schalter eingeschaltet lassen.',
			'error.networkTroubleshootingStep3' => '3. Keine Verbindung? Prüfen Sie WLAN-Internetzugang oder kontaktieren Sie den Netzbetreiber.',
			'error.suggestCheckNetwork' => 'Überprüfen Sie die Netzwerkeinstellungen.',
			'error.e2eeErrTimeout' => 'Zeitüberschreitung beim Verschlüsseln. Netzwerk prüfen und erneut versuchen.',
			'error.e2eeErrNetwork' => 'Netzwerkfehler beim Verschlüsseln, Nachricht nicht gesendet',
			'error.e2eeErrPolicyNotReady' => 'Die Ende-zu-Ende-Verschlüsselungsrichtlinie ist noch nicht bereit. Bitte später erneut versuchen',
			'error.liveRoomTitleRequired' => 'Titel erforderlich',
			'group.enterSameGroup' => 'Mit Freunden in der Nähe denselben Gruppenchat beitreten',
			'group.enterTheGroup' => 'Der Gruppe beitreten',
			'group.groupAlias' => 'Mein Spitzname in dieser Gruppe',
			'group.groupAlbum' => 'Gruppenalbum',
			'group.groupDissolve' => 'Gruppe auflösen',
			'group.groupLeave' => 'Gruppe verlassen',
			'group.groupMembers' => 'Gruppenmitglieder',
			'group.groupName' => 'Gruppenname',
			'group.mutualGroupsWithHer' => 'Gemeinsame Gruppen',
			'group.groupOwner' => 'Owner',
			'group.groupAdmin' => 'Admin',
			'group.groupGuest' => 'Ehrengast',
			'group.setAdmin' => 'Als Admin festlegen',
			'group.selectGroup' => 'Gruppe auswählen',
			'group.sureToDissolveGroup' => 'Gruppe wirklich auflösen?',
			'group.sureToLeaveGroup' => 'Gruppe wirklich verlassen?',
			'group.groupAlbumNameHint' => 'Albumname eingeben',
			'group.groupAlbumRenameTitle' => 'Album umbenennen',
			'group.groupAlbumRenamed' => 'Album umbenannt',
			'group.groupAlbumUnnamed' => 'Unbenanntes Album',
			'group.groupAlbumPhotoCount' => ({required Object count}) => '${count} Bilder',
			'group.groupAlbumPhotoIdMissing' => 'Bild-ID fehlt, Details können nicht angezeigt werden',
			'group.groupAlbumPhotoListTitle' => 'Albumbilder',
			'group.groupAlbumPhotoSelectedCount' => ({required Object count}) => '${count} ausgewählt',
			'group.groupAlbumPhotoEmpty' => 'Keine Bilder',
			'group.groupAlbumPhotoUrlMissing' => 'Bildadresse fehlt, kann nicht geöffnet werden',
			'group.groupAlbumPhotoUrlInvalid' => 'Bildadresse ungültig',
			'group.groupAlbumPhotoDetailTitle' => 'Bild-Details',
			'group.groupAlbumPhotoSetCover' => 'Als Cover festlegen',
			'group.groupAlbumPhotoPrev' => 'Zurück',
			'group.groupAlbumPhotoLikeCount' => 'Gefällt-mir',
			'group.groupAlbumPhotoCommentCount' => 'Kommentare',
			'group.groupAlbumPhotoMyLike' => 'Mein Like',
			'group.groupAlbumPhotoIdLabel' => 'Bild-ID',
			'group.e2eeKeyManagement' => 'E2EE-Schlüsselverwaltung',
			'group.e2eeKeyManagementSubtitle' => 'E2EE-Schlüssel sichern, wiederherstellen und verwalten',
			'group.e2eeTitle' => 'Ende-zu-Ende-Verschlüsselung',
			'group.e2eeEnableConfirm' => 'Nach der Aktivierung werden Gruppennachrichten Ende-zu-Ende verschlüsselt und sind nur auf den Geräten der Mitglieder lesbar. Dies kann nicht rückgängig gemacht werden. Aktivieren?',
			'group.enterGroupChat' => 'Zum Gruppenchat',
			'group.groupCreated' => 'Gruppenchat erstellt',
			'group.groupCreatedSuccess' => 'Gruppenchat erstellt. Bitte vervollständigen Sie die Gruppeninfos oder treten Sie direkt bei',
			'group.groupInfo' => 'Gruppenchat-Infos',
			'group.groupMemberRoleLabel' => 'Mitglied',
			'group.moreActions' => 'Weitere Aktionen',
			'group.noMemberWithRole' => ({required Object roleName}) => 'Keine ${roleName} vorhanden',
			'group.perfectionGroupInfo' => 'Gruppeninfos vervollständigen',
			'group.touchContactAddMember' => 'Kontakt antippen, um als Gruppenmitglied hinzuzufügen',
			'group.transferAndLeave' => 'Übertragen und verlassen',
			'group.sureToTransferAndLeave' => 'Du überträgst die Eigentümerschaft und verlässt die Gruppe. Fortfahren?',
			'group.transferredButLeaveFailed' => 'Eigentümerschaft übertragen, aber das Verlassen ist fehlgeschlagen. Bitte erneut versuchen',
			'group.noEligibleSuccessor' => 'Kein Mitglied zum Übertragen verfügbar',
			'groupCategory.title' => 'Gruppenkategorien',
			'groupCategory.createCategory' => 'Kategorie erstellen',
			'groupCategory.categoryName' => 'Kategorie-Name',
			'groupCategory.noCategory' => 'Keine Kategorien',
			'groupCategory.deleteCategory' => 'Kategorie löschen',
			'groupCategory.deleteCategoryConfirm' => 'Diese Kategorie wirklich löschen? Gruppen bleiben erhalten.',
			'groupCategory.categoryDeleted' => 'Kategorie gelöscht',
			'groupCategory.renameCategory' => 'Kategorie umbenennen',
			'groupCategory.categoryRenamed' => 'Kategorie umbenannt',
			'groupCategory.renameFailed' => 'Umbenennen fehlgeschlagen. Bitte erneut versuchen.',
			'groupCategory.deleteFailed' => 'Löschen fehlgeschlagen. Bitte erneut versuchen.',
			'groupCategory.categoryDetailTip' => 'Gruppen dieser Kategorie lassen sich in der Gruppenliste über „In Kategorie verschieben" verwalten',
			'groupDiscovery.title' => 'Gruppen entdecken',
			'groupDiscovery.searchHint' => 'Öffentliche Gruppen suchen',
			'groupDiscovery.allCategories' => 'Alle',
			'groupDiscovery.sortPopular' => 'Beliebt',
			'groupDiscovery.sortNewest' => 'Neueste',
			'groupDiscovery.emptyTitle' => 'Noch keine öffentlichen Gruppen. Schauen Sie später wieder vorbei',
			'groupDiscovery.searchEmpty' => 'Keine passenden öffentlichen Gruppen',
			'groupList.attrAll' => 'Alle',
			'groupList.attrOwner' => 'Erstellt',
			'groupList.attrManager' => 'Verwaltet',
			'groupList.attrJoin' => 'Beigetreten',
			'groupList.refresh' => 'Aktualisieren',
			'groupSchedule.title' => 'Gruppen-Termine',
			'groupSchedule.createSchedule' => 'Termin erstellen',
			'groupSchedule.scheduleTitle' => 'Termin-Titel',
			'groupSchedule.selectDate' => 'Datum wählen',
			'groupSchedule.selectTime' => 'Uhrzeit wählen',
			'groupSchedule.location' => 'Ort',
			'groupSchedule.noSchedule' => 'Keine Termine',
			'groupSchedule.startTime' => 'Beginn',
			'groupSchedule.endTime' => 'Ende',
			'groupSchedule.participants' => 'Teilnehmer',
			'groupSchedule.statusCancelled' => 'Abgesagt',
			'groupSchedule.statusInProgress' => 'Läuft',
			'groupSchedule.statusNotStarted' => 'Nicht begonnen',
			'groupSchedule.statusEnded' => 'Beendet',
			'groupSchedule.cancelSuccess' => 'Termin abgesagt',
			'groupSchedule.cancelFailed' => 'Absagen fehlgeschlagen. Bitte später erneut versuchen.',
			'groupSchedule.confirmAttend' => 'Teilnehmen',
			'groupSchedule.declineAttend' => 'Absagen',
			'groupSchedule.cancelSchedule' => 'Termin absagen',
			'groupSchedule.scheduleIdMissing' => 'Termin-ID fehlt, Details können nicht angezeigt werden',
			'groupSchedule.untitledSchedule' => 'Unbenannter Termin',
			'groupSchedule.cardViewAndAttend' => 'Details ansehen und zusagen',
			'groupTag.title' => 'Gruppen-Tags',
			'groupTag.addTag' => 'Tag hinzufügen',
			'groupTag.tagName' => 'Tag-Name',
			'groupTag.noTag' => 'Keine Tags',
			'groupTag.removeTitle' => 'Tag entfernen',
			'groupTag.removeConfirm' => 'Dieses Tag wirklich entfernen?',
			'groupTask.title' => 'To-dos',
			'groupTask.createTask' => 'To-do erstellen',
			'groupTask.editTask' => 'To-do bearbeiten',
			'groupTask.taskTitle' => 'To-don-Titel',
			'groupTask.taskDescription' => 'Beschreibung',
			'groupTask.deadline' => 'Frist',
			'groupTask.noDeadline' => 'Keine Frist',
			'groupTask.noTask' => 'Keine To-don',
			'groupTask.all' => 'Alle',
			'groupTask.pending' => 'Offen',
			'groupTask.completed' => 'Erledigt',
			'groupTask.taskSubmitted' => 'To-do eingereicht',
			'groupTask.submitTask' => 'To-do einreichen',
			'groupTask.overdue' => 'Überfällig',
			'groupTask.daysLeft' => ({required Object days}) => 'Frist in ${days} Tagen',
			'groupTask.hoursLeft' => ({required Object hours}) => 'Frist in ${hours} Std.',
			'groupTask.dueSoon' => 'Frist bald',
			'groupTask.submitFailed' => 'Einreichen fehlgeschlagen. Bitte später erneut versuchen.',
			'groupTask.pendingReview' => 'Prüfung ausstehend',
			'groupTask.taskIdMissing' => 'To-don-ID fehlt, Details können nicht angezeigt werden',
			'groupTask.taskIdMissingSubmit' => 'To-don-ID fehlt, Einreichen nicht möglich',
			'groupTask.publishedAt' => ({required Object time}) => 'Veröffentlicht ${time}',
			'groupTask.completedAt' => ({required Object time}) => 'Abgeschlossen ${time}',
			'groupVote.title' => 'Gruppen-Umfrage',
			'groupVote.createVote' => 'Umfrage erstellen',
			'groupVote.voteTitle' => 'Umfrage-Titel',
			'groupVote.noVote' => 'Keine Umfragen',
			'groupVote.voteEnded' => 'Umfrage beendet',
			'groupVote.totalVotes' => ({required Object count}) => '${count} Stimmen gesamt',
			'groupVote.voteSuccess' => 'Abstimmung gespeichert',
			'groupVote.cancelVoteSuccess' => 'Abstimmung zurückgezogen',
			'groupVote.eachOptionPerLine' => 'Eine Option pro Zeile',
			'groupVote.statusInProgress' => 'Läuft',
			'groupVote.updateVote' => 'Umfrage aktualisieren',
			'groupVote.cancelMyVote' => 'Meine Abstimmung zurückziehen',
			'groupVote.voteIdMissing' => 'Umfrage-ID fehlt, Details können nicht angezeigt werden',
			'groupVote.participantCount' => ({required Object count}) => 'Teilnehmer: ${count}',
			'groupVote.singleChoice' => 'Einfachauswahl',
			'groupVote.multipleChoice' => 'Mehrfachauswahl',
			'groupVote.endVote' => 'Abstimmung beenden',
			'groupVote.alreadyVoted' => 'Abgestimmt',
			'groupVote.selectedCount' => ({required Object count}) => '${count} ausgewählt',
			'groupVote.voteCount' => ({required Object count}) => '${count} Stimmen',
			'main.totalAssets' => 'Gesamtvermögen',
			'main.album' => 'Fotos',
			'main.appSize' => 'App-Größe',
			'main.arSa' => 'Arabisch (Saudi-Arabien)',
			'main.audio' => 'Audio',
			'main.barcodeFound' => 'Strichcode gefunden!',
			'main.botQianFan' => 'QianFan Robot',
			'main.liveRoomWhipLabel' => 'WHIP-Streaming-URL',
			'main.liveRoomWhepLabel' => 'WHEP-Empfangs-URL',
			'main.cache' => 'Cache',
			'main.camera' => 'Kamera',
			'main.changeParam' => ({required Object param}) => '${param} ändern',
			'main.chooseFromAlbum' => 'Aus Album auswählen',
			'main.clean' => 'Bereinigen',
			'main.codeSentToParam' => ({required Object param}) => 'Bestätigungscode an ${param} gesendet',
			'main.collected' => 'Favorisiert',
			'main.completed' => 'Abgeschlossen',
			'main.copied' => 'Kopiert',
			'main.darkModel' => 'Dunkler Modus',
			'main.deDd' => 'Deutsch (Deutschland)',
			'main.disable' => 'Deaktivieren',
			'main.enUs' => 'Amerikanisches Englisch',
			'main.enable' => 'Aktivieren',
			'main.expired' => 'Abgelaufen',
			'main.e2eeCollectRotating' => 'Schlüsselrotation läuft, bitte später erneut versuchen',
			'main.e2eeCollectUnsupported' => 'Server unterstützt Ende-zu-Ende-verschlüsselte Favoriten noch nicht, bitte Server aktualisieren',
			'main.favorites' => 'Favoriten',
			'main.female' => 'Weiblich',
			'main.followSystem' => 'System folgen',
			'main.frFr' => 'Französisch (Frankreich)',
			'main.from' => 'Von',
			'main.good' => 'Sehr gut',
			'main.hangup' => 'Auflegen',
			'main.iAm' => 'Ich bin',
			'main.itIt' => 'Italienisch (Italien)',
			'main.jaJp' => 'Japanisch (Japan)',
			'main.keepSecret' => 'Geheim halten',
			'main.lastActiveTime' => 'Letzte Aktivitätszeit',
			'main.lastSeenHide' => 'Online-Status ausblenden',
			'main.lastSeenNever' => 'Nie online',
			'main.lastSeenWeeksAgo' => ({required Object param}) => 'Vor ${param} Wochen',
			'main.lastSeenExactTime' => ({required Object param}) => 'Zuletzt online ${param}',
			'main.licenseAgreement' => 'Softwarelizenz- und Dienstleistungsvereinbarung',
			'main.loudspeaker' => 'Lautsprecher',
			'main.makeYourselfInvisible' => 'Unsichtbar werden',
			'main.makeYourselfVisible' => 'Sichtbar werden',
			'main.male' => 'Männlich',
			'main.manage' => 'Verwalten',
			'main.markStar' => 'Favorit',
			'main.multiSelect' => 'Mehrfachauswahl',
			'main.myFavorites' => 'Meine Favoriten',
			'main.myLive' => 'Mein Live-Stream',
			'main.name' => 'Name',
			'main.numUnit' => ({required Object param}) => '${param} Stück',
			'main.openInBrowser' => 'Im Browser öffnen',
			'main.or' => 'Oder',
			'main.otherParty' => 'Gegenüber',
			'main.packageSize' => 'Paketgröße',
			'main.peerHasHungUp' => 'Gesprächspartner hat aufgelegt',
			'main.play' => 'Abspielen',
			'main.pleaseInputParam' => ({required Object param}) => 'Bitte ${param} eingeben',
			'main.pleaseSelect' => 'Bitte auswählen',
			'main.quote' => 'Zitat',
			'main.recentlyUsed' => 'Kürzlich verwendet',
			'main.releaseEnd' => 'Zum Beenden loslassen',
			'main.memberDetail' => 'Mitgliederdetails',
			'main.replied' => 'Geantwortet',
			'main.ringing' => 'Klingelt...',
			'main.ruRu' => 'Russisch (Russland)',
			'main.selectedCount' => ({required Object count}) => 'Ausgewählt (${count})',
			'main.selected' => 'Ausgewählt',
			'main.sent' => 'Gesendet',
			'main.sentByMe' => 'Von mir gesendet',
			'main.setParam' => ({required Object param}) => '${param} einstellen',
			'main.setting' => 'Einstellungen',
			'main.siginQ' => 'Bereits ein Konto?',
			'main.source' => 'Quelle',
			'main.speakingTooShort' => 'Sprechzeit zu kurz',
			'main.speed' => 'Geschwindigkeit',
			'main.stillNeeded' => 'Noch benötigt',
			'main.storageSpace' => 'Speicherplatz',
			'main.text' => 'Text',
			'main.thisWeek' => 'Diese Woche',
			'main.titleMine' => 'Ich',
			'main.tooBad' => 'Zu schlecht',
			'main.tryAgainQ' => 'Nochmal versuchen?',
			'main.type' => 'Typ',
			'main.unanswered' => 'Unbeantwortet',
			'main.unnamed' => 'Unbenannt',
			'main.usedSpace' => 'Verwendeter Speicherplatz',
			'main.you' => 'Sie',
			'main.zhCn' => 'Vereinfachtes Chinesisch',
			'main.zhHant' => 'Traditionelles Chinesisch',
			'main.bound' => 'Gebunden',
			'main.correct' => 'Korrekt',
			'main.pendingInput' => 'Eingabe ausstehend',
			'main.lengthCheck' => 'Längenprüfung',
			'main.bugReport' => 'Fehlerbericht',
			'main.deleting' => 'Wird gelöscht...',
			'main.publish' => 'Veröffentlichen',
			'main.privacyPolicy' => 'Datenschutzrichtlinie',
			'main.termsOfService' => 'Nutzungsbedingungen',
			'main.saving' => _root.common.loading,
			'main.systemDefault' => 'Systemstandard',
			'main.gradientBlue' => 'Verlauf Blau',
			'main.gradientPurple' => 'Verlauf Lila',
			'main.copiedToClipboard' => 'In die Zwischenablage kopiert',
			'main.destroyTime' => 'Zerstörungszeit',
			'main.previewEffect' => 'Vorschau-Effekt',
			'main.thisIsTitleText' => 'Dies ist Titeltext',
			'main.thisIsAuxiliaryText' => 'Dies ist Hilfstext',
			'main.toBeCompleted' => 'Noch zu vervollständigen',
			'main.availableCount' => 'Verfügbar',
			'main.mostUsed' => 'Am häufigsten verwendet',
			'main.school' => 'Schule',
			'main.hobbiesAndInterests' => 'Hobbys & Interessen',
			'main.interests' => 'Interessen',
			'main.selectFromAlbum' => 'Aus Album auswählen',
			'main.volumeUp' => 'Lautstärke erhöhen',
			'main.volumeDown' => 'Lautstärke verringern',
			'main.fastRewind' => ({required Object seconds}) => 'Schnell zurück ${seconds} Sekunden',
			'main.pleaseTryAgain' => 'Bitte versuchen Sie es erneut',
			'main.secret' => 'Geheim',
			'main.takePhoto' => 'Foto aufnehmen',
			'main.deletingInProgressPleaseWait' => 'Wird gelöscht, bitte warten...',
			'main.collecting' => 'Wird favorisiert...',
			'main.user' => 'Benutzer',
			'main.recommended' => 'Empfohlen',
			'main.larger' => 'Größer',
			'main.fillIn' => 'Ausfüllen',
			'main.msgProtectedByComplianceKey' => 'Nachricht durch Compliance-Schlüssel geschützt',
			'main.inviterLabel' => ({required Object uid}) => 'Eingeladen von: ${uid}',
			'main.inviteeLabel' => ({required Object uid}) => 'Eingeladener: ${uid}',
			'main.mySentTab' => 'Gesendet',
			'main.reject' => 'Ablehnen',
			'main.myOrders' => 'Bestellungen',
			'main.purchaseUnlockHint' => 'Nach Kauf werden Verlauf und neue Nachrichten freigeschaltet.',
			'main.payingDots' => 'Zahlung...',
			'main.purchaseAndUnlock' => 'Jetzt kaufen & freischalten',
			'main.orderDetail' => 'Bestelldetails',
			'main.orderAmountLabel' => ({required Object currency, required Object amount}) => 'Betrag: ${currency} ${amount}',
			'main.channelPriceLabel' => ({required Object currency, required Object amount}) => 'Preis: ${currency} ${amount}',
			'main.e2eeKeyRecoveryTitle' => 'E2EE-Schlüsselverwaltung',
			'main.e2eeRecoveryMethods' => 'Wiederherstellungsmethoden',
			'main.e2eeDangerousOps' => 'Kritische Aktionen',
			'main.e2eeKeyIdLabel' => 'Schlüssel-ID',
			'main.e2eeWarnIrreversible' => '• Vorgang nicht umkehrbar',
			'main.e2eeWarnNeedRestoreOrNew' => '• Aus Backup wiederherstellen oder neuen Schlüssel erstellen',
			'main.gotIt' => 'Verstanden',
			'main.webQRLoggingIn' => 'Anmeldung...',
			'main.webQRExpired' => 'QR-Code abgelaufen',
			'main.webQRRefresh' => 'QR-Code aktualisieren',
			'main.webSwitchToQR' => 'Per QR-Code anmelden',
			'main.e2eeErrDefault' => 'E2EE fehlgeschlagen, Nachricht nicht gesendet',
			'main.e2eeErrPeerDeviceNotReady' => 'Die Sicherheitseinrichtung einiger Mitglieder ist nicht abgeschlossen, Nachricht nicht gesendet; bitte später erneut versuchen',
			'main.liveRoomTitleLabel' => 'Livestream-Titel',
			'main.liveRoomTitleHint' => 'Livestream-Titel eingeben',
			'main.lightModel' => 'Heller Modus',
			'main.safetyNumberTitle' => 'Sicherheitscode-Verifizierung',
			'main.safetyNumberHint' => 'Vergleichen Sie den Sicherheitscode persönlich oder telefonisch mit der anderen Person. Bei Übereinstimmung wird Ihre Kommunikation nicht abgehört; bei Abweichung beenden Sie sofort das Gespräch und verifizieren Sie die Identität über einen anderen Kanal. Der Verifizierungsstatus wird nur auf diesem Gerät gespeichert.',
			'main.safetyNumberCopy' => 'Kopieren',
			'main.safetyNumberCopied' => 'Kopiert',
			'main.safetyNumberMarkVerified' => 'Als verifiziert markieren',
			'main.safetyNumberMarkedVerified' => 'Als verifiziert markiert',
			'main.safetyNumberNoDevices' => 'Die Gegenseite hat Ende-zu-Ende-Verschlüsselung noch nicht aktiviert',
			'main.safetyNumberPeerDevice' => 'Gerät der Gegenseite',
			'main.safetyNumberReportRejected' => 'Der Server hat das Verifizierungsereignis abgelehnt (Signatur/Gültigkeit passt nicht), nicht markiert',
			'main.safetyNumberReportUnavailable' => 'Geräteinformationen nicht verfügbar, nicht gemeldet',
			'main.safetyNumberVerified' => '✓ Verifiziert',
			'main.safetyNumberNotVerified' => 'Nicht verifiziert',
			'main.safetyNumberDeviceCount' => ({required Object count}) => '${count} Gerät(e)',
			'main.safetyNumberReporting' => 'Verifizierungsergebnis wird gemeldet...',
			'main.safetyNumberVerifyFailed' => 'Sicherheitscode konnte nicht abgerufen werden. Bitte später erneut versuchen',
			'main.complianceKeyInfoTitle' => 'Compliance-Audit-Schlüssel',
			'main.complianceKeyInfoAlgorithm' => 'Algorithmus',
			'main.complianceKeyInfoChangedWarning' => '⚠️ Der vom Server bereitgestellte öffentliche Compliance-Schlüssel stimmt nicht mit dem lokalen Pinning überein! Falls dies keine beabsichtigte Rotation durch den Administrator ist, kontaktieren Sie sofort den Administrator und senden Sie keine verschlüsselten Nachrichten.',
			'main.complianceKeyInfoFetchedAt' => 'Abgerufen am',
			'main.complianceKeyInfoFingerprint' => 'Öffentlicher Schlüssel-Fingerabdruck',
			'main.complianceKeyInfoHint' => 'Der Compliance-Audit-Schlüssel dient der doppelten Verschlüsselung im compliance_e2ee-Modus. Weicht der obige Fingerabdruck vom Fingerabdruck ab, den der Administrator veröffentlicht hat, wurde der Server möglicherweise manipuliert.',
			'main.complianceKeyInfoKeyId' => 'Schlüssel-ID',
			'main.complianceKeyInfoLocalPin' => 'Lokales Pinning (TOFU)',
			'main.complianceKeyInfoPinnedAt' => 'Gepinnt am',
			'main.complianceKeyInfoPinnedNone' => 'Noch nicht gepinnt (wird beim nächsten Abruf automatisch gepinnt)',
			'main.complianceKeyInfoRefreshFailed' => 'Abruf fehlgeschlagen. Bitte Netzwerk prüfen und erneut versuchen',
			'main.complianceKeyInfoServerKey' => 'Vom Server bereitgestellter öffentlicher Schlüssel',
			'main.e2eeErrComplianceChanged' => 'Compliance-Audit-Schlüssel hat sich geändert, Nachricht nicht gesendet. Bitte Rotation bestätigen und erneut versuchen',
			'main.e2eeErrComplianceUnavailable' => 'Compliance-Schlüssel derzeit nicht verfügbar, Nachricht nicht gesendet. Bitte später erneut versuchen',
			'main.e2eeErrComplianceExpired' => 'Der Compliance-Schlüssel ist abgelaufen. Bitte kontaktieren Sie den Administrator',
			'main.complianceKeyRotationConfirmed' => 'Compliance-Schlüsselrotation bestätigt, Nachricht kann erneut gesendet werden',
			'main.complianceKeyRotationNoPending' => 'Keine ausstehende Schlüsseländerung zu bestätigen',
			'main.e2eeErrDeviceNotReady' => 'Sicherheitsinitialisierung dieses Geräts nicht abgeschlossen. Bitte abmelden, neu anmelden und erneut versuchen',
			'main.e2eeErrProtocolMismatch' => 'Verschlüsselungsprotokoll-Konfiguration fehlerhaft. Bitte App aktualisieren und erneut versuchen',
			'main.e2eeErrPeerSuiteUnsupported' => 'Das Gerät der Gegenseite unterstützt die erforderliche Verschlüsselungssuite nicht, Nachricht nicht gesendet. Bitte die Gegenseite zum App-Update auffordern und erneut versuchen',
			_ => null,
		} ?? switch (path) {
			'main.e2eeErrSessionExportFailed' => 'Gruppensitzungsschlüssel konnte nicht erstellt werden. Bitte später erneut versuchen',
			'main.complianceKeyNotConfigured' => 'Für diese Bereitstellung ist kein Compliance-Audit-Schlüssel konfiguriert',
			'main.mineContent' => 'Meine Inhalte',
			'main.mineCommonEntries' => 'Schnellzugriff',
			'main.mineManagementSupport' => 'Verwaltung & Hilfe',
			'main.mineSettingsSupport' => 'Einstellungen & Hilfe',
			'main.mineStorageUsage' => 'Speichernutzung',
			'mention.mentionAll' => 'Alle',
			'mention.mentionAllHint' => 'Alle Gruppenmitglieder benachrichtigen',
			'mention.noMatchedMember' => 'Keine passenden Mitglieder',
			'mention.title' => '@Erwähnungen',
			'mention.noMention' => 'Keine @Erwähnungen',
			'mention.allRead' => 'Alle gelesen',
			'mention.mentionAllDenied' => 'Nur Administratoren können @alle verwenden',
			'mention.navInfoMissing' => 'Nachrichtenposition fehlt, Sprung nicht möglich',
			'mention.pickButtonTooltip' => 'Mitglied erwähnen',
			'momentFriendPicker.confirm' => 'Fertig',
			'momentFriendPicker.confirmWithCount' => ({required Object count}) => 'Fertig (${count})',
			'momentFriendPicker.selectedCount' => ({required Object count}) => '${count} ausgewählt',
			'momentFriendPicker.emptyFriends' => 'Keine Freunde',
			'momentFriendPicker.tagLoadFailed' => 'Tags konnten nicht geladen werden',
			'momentFriendPicker.searchHint' => 'Freunde durchsuchen',
			'momentNotify.title' => 'Interaktionen',
			'momentNotify.emptyTitle' => 'Keine neuen Benachrichtigungen',
			'momentNotify.emptyHint' => '„Gefällt mir" und Kommentare von Freunden erscheinen hier',
			'momentNotify.actionLike' => 'hat Ihren Moment gelikt',
			'momentNotify.actionComment' => 'hat kommentiert',
			'momentNotify.markAllRead' => 'Alle gelesen',
			'momentNotify.clearAll' => 'Alle löschen',
			'momentNotify.clearConfirmTitle' => 'Alle Benachrichtigungen löschen?',
			'momentNotify.clearConfirmMessage' => 'Kann nicht rückgängig gemacht werden',
			'momentNotify.confirm' => 'OK',
			'momentNotify.cancel' => 'Abbrechen',
			'momentNotify.delete' => 'Löschen',
			'momentNotify.loadFailed' => 'Laden fehlgeschlagen. Bitte später erneut versuchen.',
			'organization.common.moreActions' => 'Weitere Aktionen',
			'organization.common.rename' => 'Umbenennen',
			'organization.common.close' => 'Schließen',
			'organization.common.reload' => 'Neu laden',
			'organization.common.createFailed' => 'Erstellen fehlgeschlagen',
			'organization.common.addFailed' => 'Hinzufügen fehlgeschlagen',
			'organization.common.confirmArchive' => 'Archivieren bestätigen',
			'organization.common.forbidden403' => 'Keine Berechtigung für diese Aktion (403)',
			'organization.common.noMembers' => 'Noch keine Mitglieder',
			'organization.common.targetUidHint' => 'UID des anderen Nutzers (numerisch)',
			'organization.common.uidMustBePositive' => 'Die Nutzer-UID muss eine positive Ganzzahl sein',
			'organization.common.loading' => 'Wird geladen…',
			'organization.common.loadMore' => 'Mehr laden',
			'organization.common.orgStatusPending' => 'In Prüfung',
			'organization.common.orgStatusRejected' => 'Prüfung nicht bestanden',
			'organization.home.createOrg' => 'Organisation erstellen',
			'organization.home.orgNameLabel' => 'Organisationsname (1-200 Zeichen)',
			'organization.home.createFailedWith' => ({required Object msg, required Object code}) => 'Erstellen fehlgeschlagen: ${msg} (${code})',
			'organization.home.createSubmittedPendingReview' => 'Übermittelt. Wartet auf die Prüfung durch das Betreiberteam; das Unternehmen kann nach Genehmigung normal genutzt werden',
			'organization.home.tabOrg' => 'Organisationen',
			'organization.home.myInvitations' => 'Meine Einladungen',
			'organization.home.emptyHint' => 'Du bist noch keiner Organisation beigetreten\nZum Aktualisieren nach unten ziehen oder oben rechts erstellen',
			'organization.detail.leaveOrg' => 'Organisation verlassen',
			'organization.detail.leaveOrgBody' => 'Der Austritt entzieht den Zugriff auf Verzeichnis, Gruppen, Kanäle und Dateien. Organisationsdateien bleiben erhalten. Für den Wiedereintritt ist eine Einladung erforderlich.',
			'organization.detail.leaveFailed' => 'Austritt fehlgeschlagen',
			'organization.detail.leaveOwnerHint' => 'Vor dem Austritt die Organisationsinhaberschaft übertragen',
			'organization.detail.leaveCleanupFailed' => 'Ausgetreten, aber lokale Einstellungen konnten nicht gelöscht werden. Neu starten und den gewählten Bereich prüfen',
			'organization.detail.title' => 'Organisationsdetails',
			'organization.detail.notFound' => 'Organisation nicht gefunden',
			'organization.detail.archiveOrg' => 'Organisation archivieren',
			'organization.detail.archiveConfirmBody' => 'Nach der Archivierung ist die Organisation schreibgeschützt; alle Schreiboperationen scheitern kontrolliert (fail-closed), nur Wiederherstellen (restore) entsperrt sie. Mitglieder und Daten werden nicht gelöscht.',
			'organization.detail.restoreOrg' => 'Organisation wiederherstellen',
			'organization.detail.restoreConfirmBody' => 'Nach der Wiederherstellung kehrt die Organisation in den active-Zustand zurück und Schreibzugriffe werden wieder geöffnet.',
			'organization.detail.confirmRestore' => 'Wiederherstellen bestätigen',
			'organization.detail.restoreFailed' => 'Wiederherstellen fehlgeschlagen',
			'organization.detail.archiveFailed' => 'Archivieren fehlgeschlagen',
			'organization.detail.renameOrgTitle' => 'Organisation umbenennen',
			'organization.detail.renameOrgLabel' => 'Organisationsname (1-200 Zeichen)',
			'organization.detail.renameAction' => 'Umbenennen',
			'organization.detail.renameFailed' => 'Umbenennen fehlgeschlagen',
			'organization.detail.deletionPreflight' => 'Löschvorprüfung des Kontos',
			'organization.detail.deletionPreflightDesc' => 'Anzeigen, welche Abhängigkeitsbereiche die Löschung dieses Kontos blockieren',
			'organization.detail.observedAt' => ({required Object ts}) => 'Beobachtet am: ${ts}',
			'organization.detail.factDomains' => ({required Object domains}) => 'Abgedeckte Abhängigkeitsbereiche: ${domains}',
			'organization.detail.noBlockers' => 'Keine Blocker',
			'organization.detail.blockers' => 'Blocker:',
			'organization.detail.factUnavailable' => 'Fakten der Abhängigkeitsbereiche nicht verfügbar, Löschvorprüfung abgelehnt (fail-closed)',
			'organization.detail.preflightFailed' => ({required Object msg, required Object code}) => 'Vorprüfung fehlgeschlagen: ${msg} (${code})',
			'organization.detail.myRoleAndStatus' => ({required Object role, required Object status}) => 'Meine Rolle: ${role} · Status: ${status}',
			'organization.detail.archivedBadge' => 'Organisation archiviert (schreibgeschützt)',
			'organization.detail.archivedHint' => 'Während der Archivierung werden alle Schreiboperationen abgelehnt; nur Wiederherstellen ist möglich',
			'organization.detail.defaultWsSet' => ({required Object id}) => 'Standard-Workspace: ${id}',
			'organization.detail.defaultWsUnset' => 'Standard-Workspace: nicht festgelegt',
			'organization.detail.defaultWsNote' => 'Nur ein Verweis-Fakt; steht für keine Workspace-Mitgliedschaft',
			'organization.detail.memberList' => 'Mitglieder',
			'organization.detail.memberListRestricted' => 'Mitglieder (nur für owner/admin sichtbar)',
			'organization.detail.invitationManage' => 'Einladungsverwaltung',
			'organization.detail.invitationManageRestricted' => 'Einladungsverwaltung (nur owner/admin)',
			'organization.detail.deptEntry' => 'Abteilungsverzeichnis',
			'organization.detail.deptEntryRestricted' => 'Abteilungsverzeichnis (Verwaltung nur für Berechtigte)',
			'organization.detail.more' => 'Mehr',
			'organization.detail.archiveEntrySubtitle' => 'Wird schreibgeschützt; jederzeit wiederherstellbar',
			'organization.detail.restoreEntrySubtitle' => 'Zurück zu active',
			'organization.members.title' => 'Mitglieder',
			'organization.members.loadMoreFailed' => ({required Object err}) => 'Nachladen fehlgeschlagen: ${err}',
			'organization.members.changeRole' => 'Rolle ändern',
			'organization.members.changeRoleBody' => ({required Object name, required Object from, required Object to}) => 'Die Rolle von „${name}“ wird von ${from} zu ${to} geändert.',
			'organization.members.confirmChange' => 'Änderung bestätigen',
			'organization.members.changeRoleFailed' => 'Rollenänderung fehlgeschlagen',
			'organization.members.removeMember' => 'Mitglied entfernen',
			'organization.members.removeMemberBody' => ({required Object name}) => '„${name}“ wird aus dieser Organisation entfernt. Das Konto wird nicht gelöscht.',
			'organization.members.confirmRemove' => 'Entfernen bestätigen',
			'organization.members.removeFailed' => 'Entfernen fehlgeschlagen',
			'organization.members.transferOwner' => 'Eigentümerschaft übertragen',
			'organization.members.transferOwnerBody' => ({required Object name}) => 'Eine Organisation hat genau einen Owner (C04): Bestätige, „${name}“ zum Eigentümer zu machen.\nDu wirst zum normalen Admin/Mitglied herabgestuft. Dies beeinflusst direkt die Kontrolle über die Organisation.',
			'organization.members.confirmTransfer' => 'Übertragung bestätigen',
			'organization.members.transferFailed' => 'Übertragung fehlgeschlagen',
			'organization.members.demoteToMember' => 'Zum Mitglied herabstufen',
			'organization.members.promoteToAdmin' => 'Zum Admin befördern',
			'organization.members.transferOwnerTo' => ({required Object name}) => 'Eigentümerschaft an „${name}“ übertragen',
			'organization.members.ownerCannotChangeHere' => 'Der Owner kann hier nicht geändert werden; verwende „Eigentümerschaft übertragen“',
			'organization.members.viewDetail' => 'Profil anzeigen',
			'organization.members.suspendMember' => 'Mitglied sperren',
			'organization.members.suspendBody' => ({required Object name}) => 'Zugriff von „${name}“ auf diese Organisation sperren (sofort wirksam; persönliches Konto und andere Organisationen bleiben unberührt). Jederzeit wiederherstellbar.',
			'organization.members.confirmSuspend' => 'Sperren bestätigen',
			'organization.members.suspendFailed' => 'Sperren fehlgeschlagen',
			'organization.members.restoreMember' => 'Mitglied entsperren',
			'organization.members.restoreBody' => ({required Object name}) => 'Zugriff von „${name}“ auf diese Organisation wiederherstellen.',
			'organization.members.confirmRestoreMember' => 'Entsperren bestätigen',
			'organization.members.restoreFailed' => 'Entsperren fehlgeschlagen',
			'organization.members.offboardMember' => 'Austritt (endgültig)',
			'organization.members.offboardBody' => ({required Object name}) => '${name} verlässt diese Organisation dauerhaft: removed ist ein endgültiger Zustand; ein Wiedereintritt erfordert eine neue Einladung.',
			'organization.members.confirmOffboard' => 'Austritt bestätigen',
			'organization.members.offboardFailed' => 'Austritt fehlgeschlagen',
			'organization.members.empty' => 'Keine Mitglieder',
			'organization.invitations.inviteMember' => 'Mitglied einladen',
			'organization.invitations.invitationCreated' => 'Einladung erstellt',
			'organization.invitations.tokenOnceNotice' => 'Der Empfangs-Token (token) wird nur einmal angezeigt; kopiere ihn jetzt und übermittle ihn außerhalb der App:',
			'organization.invitations.tokenCopied' => 'Token kopiert',
			'organization.invitations.copyToken' => 'Token kopieren',
			'organization.invitations.inviteFailed' => ({required Object msg, required Object code}) => 'Einladung fehlgeschlagen: ${msg} (${code})',
			'organization.invitations.acceptTitle' => 'Einladung annehmen',
			'organization.invitations.acceptBody' => ({required Object orgId}) => 'Mit der Annahme trittest du der Organisation ${orgId} bei.\nDie Einladung ist einmalig; die Mitgliedschaft entscheidet der Server.',
			'organization.invitations.confirmAccept' => 'Annehmen',
			'organization.invitations.acceptFailed' => 'Annehmen fehlgeschlagen',
			'organization.invitations.rejectTitle' => 'Einladung ablehnen',
			'organization.invitations.rejectBody' => 'Nach der Ablehnung geht die Einladung in einen Endzustand und kann nicht mehr angenommen werden.',
			'organization.invitations.confirmReject' => 'Ablehnung bestätigen',
			'organization.invitations.rejectFailed' => 'Ablehnen fehlgeschlagen',
			'organization.invitations.revokeTitle' => 'Einladung widerrufen',
			'organization.invitations.revokeBody' => 'Nach dem Widerruf geht die Einladung in einen Endzustand; die Zielperson kann sie nicht mehr mit dem Token annehmen.',
			'organization.invitations.confirmRevoke' => 'Widerruf bestätigen',
			'organization.invitations.revokeFailed' => 'Widerrufen fehlgeschlagen',
			'organization.invitations.myInvitations' => 'Meine Einladungen',
			'organization.invitations.manageInvitations' => 'Einladungsverwaltung',
			'organization.invitations.createInvitation' => 'Einladung erstellen',
			'organization.invitations.empty' => 'Keine Einladungen',
			'organization.invitations.emptyRecord' => 'Keine Einladungsdatensätze',
			'organization.invitations.orgLine' => ({required Object orgId}) => 'Organisation ${orgId}',
			'organization.invitations.invitationLine' => ({required Object invitationId}) => 'Einladung ${invitationId}',
			'organization.invitations.targetLine' => ({required Object targetUserId, required Object subtitle}) => 'Ziel ${targetUserId} · ${subtitle}',
			'organization.invitations.acceptNotice' => 'Zum direkten Annehmen tippen – kein Token nötig;\nnach der Annahme ist die Mitgliedschaft serverseitig maßgeblich.',
			'organization.invitations.revokeAction' => 'Widerrufen',
			'organization.invitations.acceptAction' => 'Einladung annehmen',
			'organization.invitations.rejectAction' => 'Ablehnen',
			'organization.departments.title' => 'Abteilungsverwaltung',
			'organization.departments.statusLine' => ({required Object status}) => 'Status: ${status}',
			'organization.departments.memberUidLine' => ({required Object userId}) => 'Mitglied ${userId}',
			'organization.departments.viewForbiddenDetail' => 'Kein Zugriff auf diese Abteilung (nur aktive Mitglieder dieser Organisation)',
			'organization.departments.viewForbidden' => 'Kein Zugriff (nur aktive Mitglieder dieser Organisation)',
			'organization.departments.loadFailedWith' => ({required Object msg, required Object code}) => 'Abteilung konnte nicht geladen werden: ${msg} (${code})',
			'organization.departments.loadFailed' => ({required Object err}) => 'Abteilung konnte nicht geladen werden: ${err}',
			'organization.departments.createSubHere' => 'Hier eine Unterabteilung erstellen',
			'organization.departments.movePickParent' => 'Verschieben (neue übergeordnete Abteilung wählen)',
			'organization.departments.addMemberByUid' => 'Mitglied hinzufügen (per UID)',
			'organization.departments.archiveDept' => 'Abteilung archivieren',
			'organization.departments.createRootDept' => 'Root-Abteilung erstellen',
			'organization.departments.deptNameLabel' => 'Abteilungsname',
			'organization.departments.createUnder' => ({required Object parent}) => 'Unter „${parent}“ erstellen',
			'organization.departments.renameDept' => 'Abteilung umbenennen',
			'organization.departments.newNameLabel' => 'Neuer Name',
			'organization.departments.renameFailed' => 'Umbenennen fehlgeschlagen',
			'organization.departments.moveDept' => 'Abteilung verschieben',
			'organization.departments.rootLevel' => 'Organisationswurzel',
			'organization.departments.moveFailed' => 'Verschieben fehlgeschlagen',
			'organization.departments.addDeptMember' => 'Abteilungsmitglied hinzufügen',
			'organization.departments.archiveConfirmBody' => ({required Object name}) => 'Nach der Archivierung von „${name}“ ist die Abteilung schreibgeschützt (Mitgliedschaften bleiben erhalten).',
			'organization.departments.archiveFailed' => 'Archivieren fehlgeschlagen',
			'organization.departments.emptyWithHint' => 'Noch keine Abteilungen – erstelle oben rechts eine',
			'organization.departments.empty' => 'Keine Abteilungen',
			'organization.departments.emptySubtitle' => 'Mehrfachmitgliedschaft: Ein Mitglied kann mehreren Abteilungen angehören; Abteilungsmitglieder müssen zuerst Mitglieder dieser Organisation sein.',
			'organization.departments.casConflictHint' => 'Die Abteilung wurde gleichzeitig geändert; der neueste Baum wurde aktualisiert, bitte erneut versuchen.',
			'organization.departments.expandNode' => ({required Object name}) => '"${name}" ausklappen',
			'organization.departments.collapseNode' => ({required Object name}) => '"${name}" einklappen',
			'organization.departments.removeMemberUid' => ({required Object userId}) => 'Mitglied ${userId} entfernen',
			'organization.departments.removeMemberConfirm' => ({required Object userId, required Object name}) => 'Mitglied ${userId} wird aus "${name}" entfernt. Die Organisationsmitgliedschaft und Rollen in anderen Abteilungen bleiben unberührt (Mehrfachmitgliedschaft).',
			'organization.departments.removeMemberFailed' => 'Entfernen des Abteilungsmitglieds fehlgeschlagen',
			'organization.departments.confirmRemoveMember' => 'Entfernen bestätigen',
			'organization.departments.setDeptAdmin' => ({required Object userId}) => '${userId} zum Abteilungsadmin ernennen',
			'organization.departments.unsetDeptAdmin' => ({required Object userId}) => 'Abteilungsadmin-Rechte von ${userId} entziehen',
			'organization.departments.setAdminFailed' => 'Festlegen des Abteilungsadmins fehlgeschlagen',
			'organization.departments.memberGovernActions' => 'Mitgliedsverwaltungsaktionen',
			'organization.picker.title' => 'Unternehmen wechseln',
			'organization.picker.switchEnterprise' => 'Unternehmen wechseln',
			'organization.picker.switchFailed' => 'Wechsel fehlgeschlagen',
			'organization.picker.switchFailedRecovered' => 'Wechsel fehlgeschlagen; vorherige Auswahl wiederhergestellt',
			'organization.picker.noneSelected' => 'Kein Unternehmen ausgewählt',
			'organization.picker.emptyHint' => 'Du bist noch keinem Unternehmen beigetreten.\nTippe unten auf „Unternehmen beitreten“ und gib den Einladungscode ein',
			'organization.picker.joinEnterprise' => 'Unternehmen beitreten',
			'organization.picker.joinOrgIdLabel' => 'Unternehmens-ID',
			'organization.picker.joinOrgIdHint' => 'Von einem Unternehmensadmin erhalten (numerische ID)',
			'organization.picker.joinOrgIdInvalid' => 'Gib eine gültige Unternehmens-ID ein (numerisch)',
			'organization.picker.joinCodeLabel' => 'Einladungscode des Unternehmens',
			'organization.picker.joinSubmit' => 'Beitreten',
			'organization.picker.joinInvalidCode' => 'Der Einladungscode des Unternehmens ist ungültig oder wurde widerrufen',
			'organization.picker.joinExpiredCode' => 'Der Einladungscode des Unternehmens ist abgelaufen',
			'organization.picker.joinFailed' => ({required Object msg}) => 'Beitritt fehlgeschlagen: ${msg}',
			'organization.picker.joinScanQr' => 'Per QR-Code beitreten',
			'organization.picker.joinCodeOnlyHint' => '8-stelligen Einladungscode eingeben',
			'organization.picker.joinConfirmTitle' => 'Beitritt bestätigen',
			'organization.picker.joinConfirmWith' => ({required Object name}) => 'Sie treten "${name}" bei',
			'organization.picker.joinConfirmWithRole' => ({required Object role, required Object name}) => 'Als ${role} "${name}" beitreten?',
			'organization.picker.joinRoleMember' => 'Einfaches Mitglied',
			'organization.picker.joinRoleAdmin' => 'Admin',
			'organization.picker.joinConfirmSubmit' => 'Beitreten',
			'organization.picker.joinBack' => 'Zurück',
			'organization.picker.joinQrHint' => 'Auf den Unternehmens-Einladungs-QR-Code richten',
			'organization.picker.joinQrInvalid' => 'Kein gültiger Unternehmens-Einladungs-QR-Code',
			'organization.inviteColleagues.title' => 'Kollegen einladen',
			'organization.inviteColleagues.tabInvite' => 'Einladen',
			'organization.inviteColleagues.tabPossible' => 'Mögliche Kollegen',
			'organization.inviteColleagues.wechatInvite' => 'Per WeChat einladen',
			'organization.inviteColleagues.wechatInviteHint' => 'Einladungscode an WeChat-Freunde senden; Beitritt über imboy',
			'organization.inviteColleagues.faceToFace' => 'Persönlich einladen',
			'organization.inviteColleagues.faceToFaceHint' => 'QR-Code scannen oder Einladungscode eingeben',
			'organization.inviteColleagues.fromWechatGroup' => 'Aus WeChat-Gruppen hinzufügen',
			'organization.inviteColleagues.fromWechatGroupHint' => 'Einladungscode in eine WeChat-Gruppe teilen',
			'organization.inviteColleagues.shareText' => ({required Object orgName, required Object code, required Object inviteUrl}) => '[${orgName}] lädt dich zu imboy ein\nEinladungscode: ${code} (7 Tage gültig)\nBeitreten über den Link: ${inviteUrl}\nimboy-App öffnen und den Code unter Kontakte > Organisation beitreten eingeben',
			'organization.inviteColleagues.shareToWechat' => 'Einladung an WeChat teilen',
			'organization.inviteColleagues.copyInviteCode' => 'Einladungscode kopieren',
			'organization.inviteColleagues.codeValidityHint' => 'Der Einladungscode ist 7 Tage gültig; bei Neugenerierung verfällt der alte Code sofort',
			'organization.inviteColleagues.possibleLoadFailed' => 'Mögliche Kollegen konnten nicht geladen werden, bitte erneut versuchen',
			'organization.inviteColleagues.revokeFailed' => 'Widerruf fehlgeschlagen, bitte später erneut versuchen',
			'organization.inviteColleagues.guideCodeMissing' => 'Noch kein aktiver Einladungscode; bitte zuerst einen Unternehmensadmin generieren lassen',
			'organization.inviteColleagues.possibleEmptyCta' => 'Kollegen einladen',
			'organization.inviteColleagues.codeLoadFailed' => 'Einladungscode konnte nicht geladen werden, bitte erneut versuchen',
			'organization.inviteColleagues.codeMissingHint' => 'Noch kein aktiver Einladungscode; erst generieren, dann teilen',
			'organization.inviteColleagues.generateCode' => 'Code generieren',
			'organization.inviteColleagues.generateForbidden' => 'Nur Unternehmensadmins können den Einladungscode generieren',
			'organization.inviteColleagues.possibleEmpty' => 'Keine ausstehenden Kollegen',
			'organization.inviteColleagues.possibleEmptyHint' => 'Lade deine Kollegen ein',
			'organization.inviteColleagues.invitedBy' => ({required Object name}) => 'Von ${name} eingeladen',
			'organization.inviteColleagues.invitedAt' => ({required Object time}) => 'Eingeladen am ${time}',
			'organization.inviteColleagues.revoke' => 'Widerrufen',
			'organization.inviteColleagues.revokeTitle' => 'Einladung widerrufen',
			'organization.inviteColleagues.revokeBody' => ({required Object name}) => 'Einladung für "${name}" widerrufen?',
			'organization.inviteColleagues.revoked' => 'Einladung widerrufen',
			'organization.inviteColleagues.groupStep1' => 'Einladungscode in deine WeChat-Gruppe teilen',
			'organization.inviteColleagues.groupStep2' => 'Kollegen kopieren den Code und öffnen die imboy-App',
			'organization.inviteColleagues.groupStep3' => 'Code unter Kontakte > Organisation beitreten eingeben',
			'organization.inviteColleagues.codeLabelWith' => ({required Object code}) => 'Einladungscode: ${code}',
			'organization.inviteQr.orgQrcode' => 'Unternehmens-QR-Code',
			'organization.inviteQr.title' => 'Mitglieder einladen',
			'organization.inviteQr.entryHint' => 'QR-Code zeigen oder Code teilen – Beitritt per Scan oder Eingabe',
			'organization.inviteQr.scanHint' => 'Andere scannen diesen Code mit dem imboy-Scanner, um dem Unternehmen beizutreten',
			'organization.inviteQr.codeLabel' => 'Unternehmens-Einladungscode',
			'organization.inviteQr.expiresWith' => ({required Object date}) => 'Gültig bis ${date}',
			'organization.inviteQr.generate' => 'Einladungscode generieren',
			'organization.inviteQr.generateFirst' => 'Noch kein aktiver Einladungscode. Ein generierter Code ist 7 Tage gültig; Beitritt per Scan oder Eingabe.',
			'organization.inviteQr.regenerate' => 'Neu generieren',
			'organization.inviteQr.regenerateTitle' => 'Einladungscode neu generieren?',
			'organization.inviteQr.regenerateBody' => 'Der aktuelle Code wird sofort ungültig; bereits geteilte QR-Codes und Codes funktionieren nicht mehr.',
			'organization.inviteQr.generateFailed' => 'Generieren fehlgeschlagen, bitte später erneut versuchen',
			'organization.inviteQr.loadFailed' => 'Einladungscode konnte nicht geladen werden',
			'organization.inviteQr.notAdmin' => 'Nur der Owner/Admin des Unternehmens kann Einladungscodes verwalten',
			'organization.inviteQr.copyCode' => 'Code kopieren',
			'organization.inviteQr.copied' => 'Einladungscode kopiert',
			'organization.inviteQr.inviteDisabledPending' => 'Das Unternehmen befindet sich in Prüfung; Mitglieder können erst nach Genehmigung eingeladen werden',
			'organization.directory.currentMembersSection' => 'Mitglieder dieser Ebene',
			'organization.directory.structureSection' => 'Organisationsstruktur',
			'organization.directory.title' => 'Verzeichnis',
			'organization.directory.deptSection' => 'Abteilungen',
			'organization.directory.allMembersSection' => 'Alle Mitglieder',
			'organization.directory.membersRestricted' => 'Die vollständige Mitgliederliste ist nur für Unternehmensadmins sichtbar; öffne eine Abteilung, um deren Mitglieder zu sehen.',
			'organization.directory.imProfileEntry' => 'IM-Profil anzeigen',
			'organization.directory.myDepartmentsSection' => 'Meine Abteilungen',
			'organization.directory.membersSection' => 'Mitglieder',
			'organization.directory.memberCountWith' => ({required Object count}) => '${count} Mitglieder',
			'organization.directory.searchHint' => 'Abteilungen oder Mitglieder suchen',
			'organization.directory.emptyDepartments' => 'Keine Unterabteilungen',
			'organization.directory.emptyMembers' => 'Keine Mitglieder',
			'organization.directory.emptySearch' => 'Keine Treffer',
			'organization.directory.switchVerifyFailed' => 'Zielorganisation nicht verfügbar oder du bist kein Mitglied mehr',
			'organization.directory.switchShellFailed' => 'Workspaces der neuen Organisation konnten nicht geladen werden',
			'organization.directory.inviteColleaguesRow' => 'Kollegen einladen...',
			'organization.directory.memberTotal' => ({required Object count}) => '${count} Mitglieder insgesamt',
			'organization.memberDetail.roleLabel' => 'Unternehmensrolle',
			'organization.memberDetail.roleRestricted' => 'Nur für Unternehmensadministratoren sichtbar',
			'organization.memberDetail.accountLabel' => 'Anmeldekonto',
			'organization.memberDetail.joinedLabel' => 'Beigetreten',
			'organization.memberDetail.workspacesTitle' => 'Berechtigte Arbeitsbereiche',
			'organization.memberDetail.workspacesEmpty' => 'Dieses Mitglied hat noch keinen Arbeitsbereich in diesem Unternehmen',
			'organization.memberDetail.workspacesFailed' => 'Berechtigte Arbeitsbereiche konnten nicht geladen werden',
			'organization.manage.renameWorkspace' => 'Workspace umbenennen',
			'organization.manage.renameWorkspaceTitle' => ({required Object name}) => '"${name}" umbenennen',
			'organization.manage.wsMembersEntry' => 'Mitglieder verwalten',
			'organization.manage.renameGroup' => 'Umbenennen',
			'organization.manage.renameGroupTitle' => ({required Object name}) => '"${name}" umbenennen',
			'organization.manage.groupGovernance' => 'Mitglieder & Rollen',
			'organization.manage.renameChannel' => 'Umbenennen',
			'organization.manage.channelAdmins' => 'Administratoren',
			'organization.manage.channelSubscribersEntry' => 'Abonnenten',
			'organization.manage.entry' => 'Unternehmensverwaltung',
			'organization.manage.entryRestricted' => 'Unternehmensverwaltung (nur Admins)',
			'organization.manage.title' => 'Unternehmensverwaltung',
			'organization.manage.orgNotFound' => 'Unternehmen nicht gefunden oder nicht sichtbar',
			'organization.manage.roleLine' => ({required Object role}) => 'Meine Rolle: ${role}',
			'organization.manage.readOnlyHint' => 'Unternehmensdaten nur lesbar; Verwaltungsaktionen nur für Inhaber/Admin',
			'organization.manage.workspaceOwnerHint' => 'Hier erscheinen nur Arbeitsbereiche, die dir gehören; Aktionen auf Unternehmensebene (Arbeitsbereich anlegen, Standard setzen) erfordern Inhaber oder Admin.',
			'organization.manage.forbiddenTitle' => 'Keine Verwaltungsberechtigung',
			'organization.manage.forbiddenBody' => 'Die Unternehmensverwaltung ist Inhaber und Admins vorbehalten. Bitte einen Admin, deine Rolle anzupassen.',
			'organization.manage.workspaceSection' => 'Arbeitsbereiche',
			'organization.manage.createWorkspace' => 'Arbeitsbereich anlegen',
			'organization.manage.workspaceNameHint' => 'Name des Arbeitsbereichs',
			'organization.manage.workspaceEmpty' => 'Noch keine Arbeitsbereiche',
			'organization.manage.workspaceEmptyHint' => 'Du bist in diesem Unternehmen noch keinem Arbeitsbereich beigetreten. Lege oben rechts einen an.',
			'organization.manage.workspaceScopeNote' => 'Hier erscheinen nur Arbeitsbereiche, denen du beigetreten bist; andere im Unternehmen nicht.',
			'organization.manage.defaultBadge' => 'Standard-Arbeitsbereich',
			'organization.manage.notDefaultBadge' => 'Nicht Standard',
			'organization.manage.archivedBadge' => 'Archiviert',
			'organization.manage.ownerBadge' => 'Ich bin Inhaber',
			'organization.manage.memberBadge' => 'Ich bin Mitglied',
			'organization.manage.setDefault' => 'Als Standard-Arbeitsbereich festlegen',
			'organization.manage.archiveWorkspace' => 'Arbeitsbereich archivieren',
			'organization.manage.archiveWorkspaceTitle' => ({required Object name}) => '「${name}」 archivieren?',
			'organization.manage.archiveWorkspaceBody' => 'Ein archivierter Arbeitsbereich wird schreibgeschützt, seine Gruppen und Kanäle nehmen keine Schreibvorgänge mehr an. Ist er der Standard-Arbeitsbereich, lege zuerst einen Ersatz fest. Die Archivierung ist umkehrbar.',
			'organization.manage.restoreWorkspace' => 'Arbeitsbereich wiederherstellen',
			'organization.manage.resourceSection' => 'Gruppen und Kanäle',
			'organization.manage.resourceNeedsWorkspace' => 'Für Gruppen und Kanäle wird zuerst ein Arbeitsbereich benötigt.',
			'organization.manage.resourceLoadFailed' => ({required Object err}) => 'Laden fehlgeschlagen: ${err}',
			'organization.manage.retry' => 'Erneut versuchen',
			'organization.manage.groupSection' => 'Unternehmensgruppen',
			'organization.manage.createGroup' => 'Gruppe anlegen',
			'organization.manage.creationRecoveryUnavailable' => 'Ergebnis unbekannt, bitte später erneut versuchen',
			'organization.manage.groupCreatedRenamePending' => ({required Object gid}) => 'Gruppe erstellt (ID: ${gid}); Name nicht gespeichert',
			'organization.manage.groupNameHint' => 'Gruppenname',
			'organization.manage.groupEmpty' => 'Noch keine Unternehmensgruppen',
			'organization.manage.groupMembers' => ({required Object count}) => '${count} Mitglieder',
			'organization.manage.dissolveGroup' => 'Gruppe auflösen',
			'organization.manage.dissolveGroupTitle' => ({required Object name}) => '「${name}」 auflösen?',
			'organization.manage.dissolveGroupBody' => 'Das Auflösen ist nicht umkehrbar. Die Mitgliedschaft endet, Nachrichtenverlauf und Auditaufzeichnungen bleiben erhalten.',
			'organization.manage.channelSection' => 'Unternehmenskanäle',
			'organization.manage.createChannel' => 'Kanal anlegen',
			'organization.manage.channelNameHint' => 'Kanalname',
			'organization.manage.channelPolicyNote' => 'Unternehmenskanäle sind immer kostenlos und nicht öffentlich: kein öffentlicher Kanalverzeichniseintrag, Mitglieder abonnieren über den Arbeitsbereich.',
			'organization.manage.channelEmpty' => 'Noch keine Unternehmenskanäle',
			'organization.manage.channelSubscribers' => ({required Object count}) => '${count} Abonnenten',
			'organization.manage.createChannelFailed' => 'Kanal konnte nicht angelegt werden',
			'organization.manage.archiveChannel' => 'Kanal archivieren',
			'organization.manage.archiveChannelTitle' => ({required Object name}) => '「${name}」 archivieren?',
			'organization.manage.archiveChannelBody' => 'Ein archivierter Kanal verschwindet aus allen öffentlichen Ansichten und ist für Mitglieder nicht mehr sichtbar. Die Archivierung ist umkehrbar.',
			'organization.manage.restoreChannel' => 'Wiederherstellen',
			'organization.manage.archivedChannelSection' => 'Archivierte Kanäle',
			'organization.contactEntry.browserEntry' => 'Verzeichnis öffnen',
			'organization.contactEntry.loadFailed' => 'Organisationsdaten konnten nicht geladen werden',
			'organization.hub.sectionResources' => 'Organisationsressourcen',
			'organization.hub.sectionAdmin' => 'Adminbereich',
			'organization.hub.zoneMembers' => 'Mitglieder',
			'organization.hub.zoneMembersDesc' => 'Verzeichnis · nach Abteilungen stöbern',
			'organization.hub.zoneDepartments' => 'Abteilungen',
			'organization.hub.zoneDepartmentsDesc' => 'Abteilungsverzeichnis und Hierarchie',
			'organization.hub.zoneGroups' => 'Gruppen',
			'organization.hub.zoneGroupsDesc' => 'Organisationsgruppen · über die Verwaltung',
			'organization.hub.zoneChannels' => 'Kanäle',
			'organization.hub.zoneChannelsDesc' => 'Organisationskanäle · über die Verwaltung',
			'organization.hub.zoneTools' => 'Werkzeuge',
			'organization.hub.zoneToolsDesc' => 'Workspaces · Projekte und Zusammenarbeit',
			'organization.hub.zoneOrgTools' => 'Enterprise-Tools',
			'organization.hub.zoneOrgToolsDesc' => 'Autorisierte Workspace-Projekte und Aufgaben dieses Unternehmens',
			'organization.hub.adminMembers' => 'Mitgliederverwaltung',
			'organization.hub.adminMembersDesc' => 'Rollen · Mitglieder entfernen',
			'organization.hub.adminInvitations' => 'Einladungsverwaltung',
			'organization.hub.adminInvitationsDesc' => 'Einladungen erstellen und widerrufen',
			'organization.hub.adminManage' => 'Organisationsverwaltung',
			'organization.hub.adminManageDesc' => 'Workspaces · Gruppen · Kanäle',
			'organization.wsMembers.title' => ({required Object ws}) => 'Workspace-Mitglieder · ${ws}',
			'organization.wsMembers.invite' => 'Mitglieder einladen',
			'organization.wsMembers.inviteHint' => 'Kontakte über den bestehenden Assistenten einladen (nur Workspace-Owner)',
			'organization.wsMembers.readOnlyHint' => 'Schreibgeschützte Ansicht; Schreibaktionen nur für den Workspace-Owner.',
			'organization.wsMembers.memberCount' => ({required Object count}) => 'Mitglieder ${count}',
			'organization.wsMembers.notFound' => 'Workspace nicht gefunden oder nicht sichtbar',
			'organization.wsMembers.roleOwner' => 'Owner',
			'organization.wsMembers.roleMember' => 'Mitglied',
			'organization.wsMembers.roleGuest' => 'Gast',
			'organization.wsMembers.changeRole' => 'Rolle ändern',
			'organization.wsMembers.setRoleMember' => 'Als Mitglied festlegen',
			'organization.wsMembers.setRoleGuest' => 'Als Gast festlegen',
			'organization.wsMembers.transferOwner' => 'Owner übertragen',
			'organization.wsMembers.transferOwnerTitle' => ({required Object name}) => 'Owner von "${name}" übertragen?',
			'organization.wsMembers.transferOwnerBody' => 'Danach bist du nicht mehr Workspace-Owner; die Governance-Rechte gehen an die neue Person über und können zurückübertragen werden.',
			'organization.wsMembers.removeMember' => 'Mitglied entfernen',
			'organization.wsMembers.removeTitle' => ({required Object name}) => '"${name}" entfernen?',
			'organization.wsMembers.removeBody' => 'Die Person verlässt den Workspace; bleibt sie Projekteigentümerin oder hat offene Aufgaben, lehnt der Server ab und listet die Konflikte.',
			'organization.wsMembers.archivedReadOnly' => 'Workspace archiviert: Governance-Schreibaktionen sind serverseitig deaktiviert.',
			'organization.tools.title' => 'Enterprise-Tools',
			'organization.tools.titleWithOrg' => ({required Object name}) => '${name} · Enterprise-Tools',
			'organization.tools.scopeNote' => 'Es werden nur Workspaces dieses Unternehmens mit deiner Mitgliedschaft samt Projekte gelistet; Aufgaben und Meilensteine liegen in der Projektdetailseite.',
			'organization.tools.archivedNote' => 'Unternehmen archiviert: Der Tool-Bereich ist schreibgeschützt.',
			'organization.tools.workspaceEmpty' => 'Keine beigetretenen Workspaces',
			'organization.tools.workspaceEmptyHint' => 'Workspaces dieses Unternehmens ohne deine Mitgliedschaft erscheinen hier nicht.',
			'organization.tools.projectCount' => ({required Object count}) => 'Projekte ${count}',
			'organization.tools.projectsEmpty' => 'Noch keine Projekte',
			'organization.tools.projectsError' => ({required Object err}) => 'Projekte laden fehlgeschlagen: ${err}',
			'organization.tools.moreInWorkspaceShell' => 'Alle Workspaces durchsuchen',
			'organization.tools.moreInWorkspaceShellHint' => 'Globalen Workspace-Umschalter öffnen (unternehmensübergreifend).',
			'organization.chart.zoomIn' => 'Vergrößern',
			'organization.chart.zoomOut' => 'Verkleinern',
			'organization.chart.fit' => 'An Fenster anpassen',
			'organization.chart.expand' => 'Unterabteilungen ausklappen',
			'organization.chart.collapse' => 'Unterabteilungen einklappen',
			'organization.chart.gestureHint' => 'Ziehen zum Verschieben · Zusammen-/Auseinanderziehen zum Zoomen',
			'organization.chart.directMembers' => ({required Object count}) => '${count} Mitglieder auf dieser Ebene',
			'organization.experienceUi.switchSpace' => 'Space wechseln',
			'organization.experienceUi.personalSpace' => 'Persönlicher Space',
			'organization.experienceUi.enterpriseSpaces' => 'Unternehmens-Spaces',
			'organization.experienceUi.currentSpace' => 'Aktueller Space',
			'organization.experienceUi.enterpriseInfo' => 'Unternehmensinfo',
			'organization.experienceUi.collaborationSpace' => 'Kollaborations-Spaces',
			'organization.experienceUi.groupContent' => 'Gruppeninhalte',
			'organization.experienceUi.groupCollaboration' => 'Gruppenzusammenarbeit',
			'organization.experienceUi.defaultWorkspace' => 'Standard-Arbeitsbereich',
			'organization.experienceUi.defaultAvailable' => 'Eingerichtet',
			'organization.experienceUi.defaultUnknown' => 'Vorübergehend nicht verfügbar',
			'organization.experienceUi.defaultHint' => 'Tritt dem entsprechenden Arbeitsbereich bei, um darauf zuzugreifen. Die Standardeinstellung gewährt keinen automatischen Zugriff.',
			'organization.experienceUi.accountCheck' => 'Prüfungen vor der Kontolöschung',
			'organization.experienceUi.workspaceContext' => ({required Object name}) => 'Arbeitsbereich: ${name}',
			'organization.experienceUi.noIntro' => 'Keine Beschreibung',
			'passport.loginHistoryToggle' => 'Anmeldeverlauf anzeigen',
			'passport.hintEmail' => 'Bitte E-Mail eingeben',
			'passport.hintMobile' => 'Bitte Mobilfunknummer eingeben',
			'passport.hintPassword' => 'Bitte Passwort eingeben',
			'passport.hintVerifyCode' => 'Bitte Bestätigungscode eingeben',
			'passport.getVerifyCode' => 'Code anfordern',
			'passport.oneKeyLogin' => 'Schnellanmeldung',
			'passport.qrCodeExpired' => 'QR-Code abgelaufen, bitte neu scannen',
			'passport.qrCodeUsed' => 'Dieser QR-Code wurde bereits verwendet',
			'passport.qrConnecting' => 'Verbindung wird hergestellt...',
			'passport.qrLoginAction' => 'Anmeldung bestätigen',
			'passport.qrLoginCancelled' => 'Anmeldung wurde abgebrochen',
			'passport.qrLoginCancelledByMe' => 'Sie haben die Anmeldung abgebrochen',
			'passport.qrLoginConfirming' => 'Anmeldung läuft...',
			'passport.qrLoginSuccess' => 'Angemeldet',
			'passport.qrWebLoginDesc' => 'Bitte bestätigen Sie die Anmeldung dieses Kontos im Web',
			'passport.qrWebLoginTitle' => 'Web-Anmeldung bestätigen',
			'passport.alipayNotSupportedWeb' => 'Alipay-Anmeldung wird im Web nicht unterstützt',
			'passport.oneKeyNotSupportedWeb' => 'One-Tap-Login wird im Web nicht unterstützt',
			'passport.oneKeyInitFailed' => 'One-Tap-Login konnte nicht initialisiert werden, bitte später erneut versuchen',
			'passport.oneKeyNoSimCard' => 'Das aktuelle Netzwerk wird nicht unterstützt oder das Handy hat keine SIM-Karte',
			'passport.cannotGetScreenSize' => 'Bildschirmgröße konnte nicht ermittelt werden',
			'passport.oneKeyFailedRetry' => 'One-Tap-Login fehlgeschlagen, bitte Netzwerk prüfen und erneut versuchen',
			'splash.slogan' => 'Frei kommunizieren.',
			'talkRecord.uploadProgressRegister' => 'Upload wird vorbereitet',
			'talkRecord.uploadProgressUpload' => 'Audio wird hochgeladen',
			'talkRecord.uploadProgressConfirm' => 'Audio wird bestätigt',
			'talkRecord.uploadProgressSubmitting' => 'Speicherung wird übermittelt',
			'talkRecord.uploadProgressCompleted' => 'Übermittelt; Audioverarbeitung ausstehend',
			'talkRecord.uploadProgressFailed' => 'Upload unvollständig; erneut versuchen',
			'talkRecord.uploadProgressParts' => ({required Object confirmed, required Object total}) => 'Bestätigte Teile: ${confirmed}/${total}',
			'talkRecord.aiServicesTitle' => 'KI-Dienste',
			'talkRecord.aiServicesSubtitle' => 'Verwende eigene API-Konten. Die Anbieter berechnen die Nutzung.',
			'talkRecord.aiMinimaxTitle' => 'MiniMax',
			'talkRecord.aiZhipuTitle' => 'Zhipu GLM-5.3-Flash',
			'talkRecord.aiMinimaxPurpose' => 'Audiotranskription und vorläufige Sprecherlabels',
			'talkRecord.aiZhipuPurpose' => 'Entwürfe für Zusammenfassungen, Entscheidungen und Aufgaben',
			'talkRecord.aiConfigured' => 'Auf diesem Gerät eingerichtet',
			'talkRecord.aiNotConfigured' => 'Nicht eingerichtet',
			'talkRecord.aiLoading' => 'Gerätekonfiguration wird gelesen…',
			'talkRecord.aiDeviceOnlyNotice' => 'Schlüssel werden nur für dieses Konto auf diesem Gerät verschlüsselt gespeichert. Kein Upload zu IMBoy, kein Cloud-Backup und keine Geräteübertragung. Auf neuen Geräten erneut eingeben.',
			'talkRecord.aiEnterprisePolicyNotice' => 'Ein gespeicherter Schlüssel erlaubt noch keine externe Verarbeitung. Unternehmensaufnahmen erfordern die Freigabe der Unternehmensrichtlinie und die Zustimmung zu jeder Verarbeitung.',
			'talkRecord.aiMaxNotice' => 'Nutzt die separat berechnete allgemeine Zhipu-API. Ein jährlicher Coding Plan Max deckt diese Nutzung nicht automatisch ab. Transkripte werden an Zhipu gesendet.',
			'talkRecord.aiAudioExternalNotice' => 'Für Transkriptionen wird Audio an MiniMax gesendet; Gebühren sind möglich. Pro Anfrage gelten höchstens 500 Sekunden und 50 MB. Der Ablauf prüft und teilt Audio entsprechend.',
			'talkRecord.aiValidationNotice' => 'Speichern prüft den Schlüssel nicht und sendet weder Audio noch Text. Eine echte Prüfung kann kostenpflichtig sein und erfordert eine gesonderte Bestätigung.',
			'talkRecord.aiAccountChanged' => 'Konto oder Bereitstellung wurde geändert. Gehe zurück und öffne die Seite erneut. Die Eingabe wurde gelöscht.',
			'talkRecord.aiCredentialChanged' => 'Die Gerätekonfiguration wurde geändert oder ist unvollständig. Schlüssel erneut eingeben und speichern oder zurückgehen und erneut versuchen.',
			'talkRecord.aiInvalidKey' => 'Gib 16–4096 ASCII-Zeichen ohne Leerzeichen, Zeilenumbrüche oder Steuerzeichen ein.',
			'talkRecord.aiStorageFailed' => 'Der sichere Gerätespeicher konnte nicht gelesen oder beschrieben werden. Konfiguration unbestätigt. Erneut versuchen; keine Speicherung als Klartext.',
			'talkRecord.aiUnsupportedPlatform' => 'Der sichere Gerätespeicher ist auf dieser Plattform noch nicht geprüft. Schlüssel können nicht gespeichert werden.',
			'talkRecord.aiKeyPlaceholder' => 'API-Schlüssel eingeben',
			'talkRecord.aiReplacePlaceholder' => 'Neuen API-Schlüssel eingeben; gespeicherte Schlüssel werden nie vorbefüllt',
			'talkRecord.aiSaveAction' => 'Auf diesem Gerät speichern',
			'talkRecord.aiReplaceAction' => 'Geräteschlüssel ersetzen',
			'talkRecord.aiDeleteAction' => 'Geräteschlüssel löschen',
			'talkRecord.aiSaving' => 'Wird gespeichert…',
			'talkRecord.aiSaved' => 'Auf diesem Gerät gespeichert. Der Schlüssel wurde nicht geprüft.',
			'talkRecord.aiDeleted' => 'Gerätekonfiguration gelöscht. Aufnahmen und vorhandene Ergebnisse bleiben erhalten.',
			'talkRecord.aiReplaceTitle' => 'Geräteschlüssel ersetzen?',
			'talkRecord.aiReplaceNotice' => 'Ersetzt nur die Einstellung dieses Dienstes für das aktuelle Konto auf diesem Gerät. Andere Konten und gespeicherte Aufnahmen bleiben unverändert.',
			'talkRecord.aiDeleteTitle' => 'Geräteschlüssel löschen?',
			'talkRecord.aiDeleteNotice' => 'Stoppt neue Anfragen an diesen Dienst. Aufnahmen und Ergebnisse bleiben erhalten. Bereits an den Anbieter gesendete Anfragen können nicht zurückgerufen werden.',
			'talkRecord.aiCancel' => 'Abbrechen',
			'talkRecord.aiDoubaoTitle' => 'Doubao Speech 2.0',
			'talkRecord.aiDoubaoPurpose' => 'Audiotranskription und temporäre Sprecherlabels',
			'talkRecord.aiDoubaoExternalNotice' => 'Audio wird zur Transkription an Volcengine Doubao Speech gesendet. Anbietergebühren können anfallen. API-Key nur auf diesem Gerät; MiniMax-Keys werden nicht übernommen.',
			'talkRecord.aiDoubaoPendingNotice' => 'Die Doubao-Transkription ist noch nicht angebunden. Nur Geräteeinstellungen können gespeichert werden. Speichern prüft keine Verbindung und aktiviert keine Transkription.',
			'talkRecord.aiProviderPending' => 'Der Anbieter verarbeitet noch. Fortschritt gespeichert. Später nur abfragen; Audio wird nicht erneut gesendet.',
			'talkRecord.aiProviderCancel' => 'Transkription stoppen',
			'talkRecord.aiProviderCancelNotice' => 'Widerruft IMBoy-Zugriff und Vorgangsrechte. Anbieter-Stopp oder Erstattung werden nicht garantiert.',
			'talkRecord.aiProviderResubmit' => 'Audio erneut senden',
			'talkRecord.aiProviderResubmitNotice' => 'Erstellt eine neue Transkription; doppelte Gebühren sind möglich. Der ursprüngliche Auftrag bleibt. Erneut senden und dieser Verarbeitung zustimmen?',
			'talkRecord.aiProviderCancelled' => 'Transkription gestoppt. Vorhandenes Audio bleibt erhalten.',
			'talkRecord.aiProviderResumePreparation' => 'Transkription weiter vorbereiten',
			'talkRecord.aiProviderResumeNotice' => 'Der ursprüngliche Auftrag wurde noch nicht übermittelt. Audioquelle mit aktuellen Rechten und Einwilligung erneut vorbereiten.',
			'welcome.step1Title' => 'Einfache Verbindung',
			'welcome.step1Desc' => 'Erleben Sie die Freude nahtloser Kommunikation. Jederzeit, überall.',
			'welcome.step2Title' => 'Sicher & Privat',
			'welcome.step2Desc' => 'Ende-zu-Ende-Verschlüsselung Hält Ihre persönlichen Momente streng vertraulich.',
			'welcome.step3Title' => 'Bereit zum Erkunden?',
			_ => null,
		} ?? switch (path) {
			'welcome.step3Desc' => 'Treten Sie einer lebendigen Gemeinschaft bei. Lassen Sie das Gespräch beginnen!',
			'welcome.next' => 'Weiter',
			'welcome.getStarted' => 'Loslegen',
			'welcome.skip' => 'Überspringen',
			'workspace.navOverview' => 'Übersicht',
			'workspace.navProjects' => 'Projekte',
			'workspace.navChannels' => 'Kanäle',
			'workspace.navGroups' => 'Gruppen',
			'workspace.pickerTitle' => 'Mein Arbeitsbereich',
			'workspace.switchWorkspace' => 'Arbeitsbereich wechseln',
			'workspace.pickerEmptyTitle' => 'Noch kein Arbeitsbereich',
			'workspace.pickerEmptySubtitle' => 'Erstellen Sie einen Arbeitsbereich und starten Sie in 3 Minuten die Teamarbeit (Announcements-Kanal und General-Gruppe werden automatisch erstellt)',
			'workspace.archivedBadge' => 'Archiviert',
			'workspace.emptyNoWorkspace' => 'Bitte zuerst einen Arbeitsbereich auswählen oder erstellen',
			'workspace.experienceModePersonal' => 'Persönlich',
			'workspace.switchToPersonal' => 'Zum persönlichen Modus wechseln',
			'workspace.createTitle' => 'Arbeitsbereich erstellen',
			'workspace.createDesc' => 'Mit einer Erstellung wird alles automatisch angelegt: Arbeitsbereich, Sie (Owner als Arbeitsbereich-Mitglied), Announcements-Kanal und General-Gruppe. Alles erfolgreich oder vollständiger Rollback.',
			'workspace.createNameLabel' => 'Arbeitsbereichsname',
			'workspace.createNameHint' => 'z. B. Website-Relaunch-Team',
			'workspace.createNameRequired' => 'Arbeitsbereichsname darf nicht leer sein',
			'workspace.createSubmit' => 'Erstellen',
			'workspace.createEntry' => 'Arbeitsbereich erstellen',
			'workspace.createSuccess' => 'Arbeitsbereich erstellt',
			'workspace.createIdempotentHit' => 'Arbeitsbereich mit diesem Namen existiert bereits, wird direkt geöffnet',
			'workspace.createTemplateTitle' => 'Wird automatisch initialisiert',
			'workspace.createTemplateChannel' => 'Announcements-Kanal (Sie werden Kanal-Herausgeber und Abonnent)',
			'workspace.createTemplateGroup' => 'General-Gruppe (Sie werden Gruppenmitglied)',
			'workspace.createTemplateOwner' => 'Sie werden Arbeitsbereich-Owner (Arbeitsbereich-Mitglied)',
			'workspace.overviewTitle' => 'Übersicht',
			'workspace.overviewResources' => 'Ressourcenüberblick',
			'workspace.overviewPinnedContent' => 'Angepinnte Kanalinhalte',
			'workspace.overviewPinnedEmpty' => 'Noch keine angepinnten Kanalinhalte; Gruppenankündigungen werden hier nicht gebündelt (sie gehören zu den einzelnen Gruppen)',
			'workspace.overviewRecentFiles' => 'Neueste Dateien',
			'workspace.overviewRecentFilesEmpty' => 'Zuletzt hochgeladene Dateien erscheinen hier; Anhänge sind auch in den einzelnen Kanälen sichtbar',
			'workspace.membersTitle' => 'Arbeitsbereich-Mitglieder',
			'workspace.membersCountLabel' => ({required Object count}) => '${count} Mitglieder',
			'workspace.membersEmpty' => 'Keine Arbeitsbereich-Mitglieder',
			'workspace.membersEmptySubtitle' => 'Laden Sie registrierte Nutzer als Arbeitsbereich-Mitglieder ein (Owner / Member / Guest)',
			'workspace.membersViewAll' => 'Alle anzeigen',
			'workspace.projectsEmptyTitle' => 'Noch keine Projekte',
			'workspace.projectsEmptySubtitle' => 'Projekte dienen der Verfolgung klarer Lieferziele; gilt ebenso für Community-Arbeitsbereiche mit nur Kanälen und Gruppen',
			'workspace.channelsEmptyTitle' => 'Noch keine Arbeitsbereich-Kanäle',
			'workspace.channelsEmptySubtitle' => 'Kanäle dienen der laufenden Veröffentlichung von Inhalten (Ankündigungen/Material); für Diskussionen bitte in die Gruppen',
			'workspace.channelTileSubtitle' => ({required Object count}) => '${count} Abonnenten',
			'workspace.channelDetailTitle' => 'Kanal',
			'workspace.groupsEmptyTitle' => 'Noch keine Arbeitsbereich-Gruppen',
			'workspace.groupsEmptySubtitle' => 'Gruppen sind der Echtzeit-Diskussionsraum im Arbeitsbereich (einziger Einstieg für Chats)',
			'workspace.groupTileSubtitle' => ({required Object count}) => '${count} Gruppenmitglieder',
			'workspace.inviteTitle' => 'Arbeitsbereich-Mitglieder einladen',
			'workspace.inviteDesc' => 'Nur registrierte Nutzer können eingeladen werden; der Arbeitsbereich-Beitritt umfasst weder Gruppe noch Kanal-Abo – gleichzeitig der General-Gruppe beitreten und eine Announcements-Kanal-Einladung senden ist möglich',
			'workspace.inviteSearchHint' => 'Nach Nutzername / Nutzer-ID suchen',
			'workspace.inviteEntry' => 'Arbeitsbereich-Mitglieder einladen',
			'workspace.inviteJoinGroupOption' => 'Gleichzeitig der General-Gruppe beitreten (als Gruppenmitglied)',
			'workspace.inviteSubscribeChannelOption' => 'Gleichzeitig eine Announcements-Kanal-Einladung senden',
			'workspace.inviteOptionUnavailable' => 'Zugehörige Ressource nicht gefunden, diese Option ist nicht verfügbar',
			'workspace.inviteSubmit' => 'Einladung senden',
			'workspace.inviteResultsTitle' => 'Ergebnisse (drei unabhängige)',
			'workspace.inviteResultWorkspace' => 'Dem Arbeitsbereich beigetreten (als Arbeitsbereich-Mitglied)',
			'workspace.inviteResultGroup' => 'Der General-Gruppe beigetreten (als Gruppenmitglied)',
			'workspace.inviteResultChannel' => 'Announcements-Kanal-Einladung gesendet (nach Annahme wird der Empfänger Abonnent)',
			'workspace.resultIdle' => 'Nicht ausgeführt',
			'workspace.resultRunning' => 'Läuft',
			'workspace.resultSuccess' => 'Erfolgreich',
			'workspace.resultFailed' => 'Fehlgeschlagen',
			'workspace.joinEntry' => 'Arbeitsbereich beitreten',
			'workspace.joinByTeamCode' => 'Arbeitsbereich per Teamcode beitreten',
			'workspace.joinTitle' => 'Arbeitsbereich beitreten',
			'workspace.joinDesc' => 'Geben Sie den Team-Code ein, um dem Arbeitsbereich beizutreten',
			'workspace.joinCodeLabel' => 'Team-Code',
			'workspace.joinCodeHint' => '8 Zeichen, Großbuchstaben oder Ziffern',
			'workspace.joinSubmit' => 'Beitreten',
			'workspace.joinSuccess' => ({required Object name}) => '„${name}“ beigetreten',
			'workspace.joinAlreadyMember' => 'Sie sind bereits in diesem Arbeitsbereich',
			'workspace.joinInvalidCode' => 'Team-Code ungültig oder abgelaufen',
			'workspace.joinExpiredCode' => 'Team-Code abgelaufen',
			'workspace.inviteCodeSectionTitle' => 'Einladung per Team-Code',
			'workspace.inviteCodeGenerate' => 'Team-Code generieren',
			'workspace.inviteCodeCopy' => 'Kopieren',
			'workspace.inviteCodeRevoke' => 'Widerrufen',
			'workspace.inviteCodeExpiresAt' => ({required Object expiresAt}) => 'Gültig bis ${expiresAt}',
			'workspace.roleOwner' => 'Owner',
			'workspace.roleMember' => 'Member',
			'workspace.roleGuest' => 'Guest',
			'workspace.removeMemberTitle' => ({required Object name}) => 'Arbeitsbereich-Mitglied ${name} entfernen',
			'workspace.removeMemberDesc' => 'Nach dem Entfernen erlischt der Arbeitsbereich-Zugang; hat die Person noch offene Aufgaben oder leitet Projekte, liefert der Server eine Konfliktliste und bricht das Entfernen ab',
			'workspace.removeMemberConfirm' => 'Entfernen bestätigen',
			'workspace.changeRoleTitle' => ({required Object name}) => 'Arbeitsbereich-Rolle von ${name} ändern',
			'workspace.transferTitle' => ({required Object name}) => 'Haupt-Owner an ${name} übertragen',
			'workspace.transferDesc' => 'Nach der Übertragung werden Sie normales Arbeitsbereich-Mitglied (Member), die andere Person erhält die volle Kontrolle',
			'workspace.transferConfirm' => 'Übertragung bestätigen',
			'workspace.governanceTitle' => 'Arbeitsbereich-Governance',
			'workspace.brandingEntry' => 'Branding (Name / Logo / Hauptfarbe)',
			'workspace.archiveEntry' => 'Arbeitsbereich archivieren',
			'workspace.restoreEntry' => 'Arbeitsbereich wiederherstellen',
			'workspace.archiveTitle' => 'Arbeitsbereich archivieren',
			'workspace.archiveDesc' => 'Nach der Archivierung gilt für alle nur Lesen (Schreibzugriffe werden vom Server abgelehnt); jederzeit wiederherstellbar',
			'workspace.archiveConfirm' => 'Archivierung bestätigen',
			'workspace.restoreTitle' => 'Arbeitsbereich wiederherstellen',
			'workspace.restoreDesc' => 'Nach der Wiederherstellung ist der Arbeitsbereich wieder les- und schreibbar',
			'workspace.restoreConfirm' => 'Wiederherstellung bestätigen',
			'workspace.archivedBanner' => 'Arbeitsbereich archiviert: Inhalte sichtbar, Schreibzugriffe deaktiviert; der Owner kann auf der Mitgliedseite wiederherstellen',
			'workspace.brandingTitle' => 'Arbeitsbereich-Branding',
			'workspace.brandingNameLabel' => 'Brandname',
			'workspace.brandingLogoLabel' => 'Logo-URL',
			'workspace.brandingLogoHint' => 'https://… (URL des Arbeitsbereich-Logos)',
			'workspace.brandingColorLabel' => 'Hauptfarbe primaryColor',
			'workspace.brandingColorHint' => '#2474E5',
			'workspace.brandingColorHelper' => 'Nur #RRGGBB / #AARRGGBB; ungültige Werte fallen auf die Standard-Designfarbe zurück',
			'workspace.brandingColorInvalid' => 'Ungültiges Format der Hauptfarbe, nur #RRGGBB / #AARRGGBB',
			'workspace.brandingSaved' => 'Branding-Einstellungen gespeichert',
			'workspace.brandingPreview' => 'Vorschau der Hauptfarbe',
			'workspace.brandingPreviewApplied' => 'Die Hauptfarbe gilt im gesamten Arbeitsbereich',
			'workspace.brandingPreviewFallback' => 'Ohne Angabe oder bei ungültigem Wert gilt die Standard-Designfarbe',
			'workspace.projectCreateEntry' => 'Neues Projekt',
			'workspace.projectCreateTitle' => 'Neues Projekt',
			'workspace.projectNameLabel' => 'Projektname',
			'workspace.projectNameHint' => 'z. B. Website-Relaunch',
			'workspace.projectNameRequired' => 'Projektname darf nicht leer sein',
			'workspace.projectDescLabel' => 'Projektbeschreibung (optional)',
			'workspace.projectDescHint' => 'Was soll dieses Projekt liefern?',
			'workspace.projectSubmit' => 'Erstellen',
			'workspace.projectCreateSuccess' => 'Projekt erstellt',
			'workspace.projectDetailTitle' => 'Projektdetails',
			'workspace.projectOwnerLabel' => 'Verantwortlich',
			'workspace.projectStatusLabel' => 'Status',
			'workspace.projectStatusActive' => 'In Bearbeitung',
			'workspace.projectStatusDone' => 'Abgeschlossen',
			'workspace.projectMarkDone' => 'Als abgeschlossen markieren',
			'workspace.projectReopen' => 'Projekt erneut öffnen',
			'workspace.projectStatusChanged' => 'Projektstatus aktualisiert',
			'workspace.projectTasksSection' => 'Aufgaben',
			'workspace.taskNewEntry' => 'Neue Aufgabe',
			'workspace.taskFormCreateTitle' => 'Neue Aufgabe',
			'workspace.taskFormEditTitle' => 'Aufgabe bearbeiten',
			'workspace.taskTitleLabel' => 'Aufgabentitel',
			'workspace.taskTitleRequired' => 'Aufgabentitel darf nicht leer sein',
			'workspace.taskAssigneeLabel' => 'Verantwortlich (Arbeitsbereich-Mitglied)',
			'workspace.taskAssigneeNone' => 'Vorerst nicht zuweisen',
			'workspace.taskAssigneeRefresh' => 'Kandidaten aktualisieren',
			'workspace.taskSubmitCreate' => 'Aufgabe erstellen',
			'workspace.taskSubmitSave' => 'Speichern',
			'workspace.taskCreatedToast' => 'Aufgabe erstellt',
			'workspace.taskExistingToast' => 'Aufgabe mit gleichem Titel existiert bereits, vorhandene Aufgabe wird verwendet',
			'workspace.taskUpdatedToast' => 'Aufgabe gespeichert',
			'workspace.taskFilterAll' => 'Alle',
			'workspace.taskStatusTodo' => 'Offen',
			'workspace.taskStatusDoing' => 'In Bearbeitung',
			'workspace.taskStatusReview' => 'In Prüfung',
			'workspace.taskStatusDone' => 'Abgeschlossen',
			'workspace.taskAdvanceTo' => ({required Object status}) => 'Weiter zu „${status}“',
			'workspace.taskFallbackMenuTitle' => ({required Object title}) => '${title} zurücksetzen auf…',
			'workspace.taskStatusMovedToast' => ({required Object status}) => 'Verschoben zu „${status}“',
			'workspace.taskEmptyTitle' => 'Noch keine Aufgaben',
			'workspace.taskEmptySubtitle' => 'Verfolgen Sie die Ausführung in vier Status: Offen → In Bearbeitung → In Prüfung → Abgeschlossen',
			'workspace.projectsLoadMore' => 'Mehr laden',
			'workspace.projectW2SectionTitle' => 'Projektzusammenarbeit',
			'workspace.projectMembersEntry' => 'Mitglieder',
			'workspace.projectMilestonesEntry' => 'Meilensteine',
			'workspace.projectChannelsEntry' => 'Projektkanäle',
			'workspace.projectInsightsEntry' => 'Inhaltsübersicht',
			'workspace.projectNoPermission' => 'Keine Berechtigung: Nur Projektmitglieder, die Projektleitung oder der Arbeitsbereich-Owner können dies ansehen',
			'workspace.projectGuestReadonly' => 'Als Gast (Guest) ist das Projekt nur lesbar',
			'workspace.projectLoadMore' => 'Mehr laden',
			'workspace.projectMembersTitle' => 'Projektmitglieder',
			'workspace.projectMemberEmptyTitle' => 'Noch keine Projektmitglieder',
			'workspace.projectMemberEmptySubtitle' => 'Die Projektleitung kann registrierte Nutzer in dieses Projekt einladen',
			'workspace.projectMemberInviteTitle' => 'Projektmitglieder einladen',
			'workspace.projectMemberInviteFieldHint' => 'ID des einzuladenden registrierten Nutzers',
			'workspace.projectMemberInviteInvalidUid' => 'Bitte eine gültige Nutzer-ID eingeben',
			'workspace.projectMemberInviteSubmit' => 'Einladen',
			'workspace.projectMemberInviteSuccess' => 'Zu den Projektmitgliedern hinzugefügt',
			'workspace.projectMemberInviteExisting' => 'Dieser Nutzer ist bereits Projektmitglied',
			'workspace.projectMemberRemoveConfirmTitle' => ({required Object name}) => 'Projektmitglied ${name} entfernen',
			'workspace.projectMemberRemoveConfirmDesc' => 'Nach dem Entfernen verliert der Nutzer den Zugriff auf Projektinhalte (erneute Einladung möglich)',
			'workspace.projectMemberRemoveSubmit' => 'Entfernen',
			'workspace.projectMemberRemovedToast' => 'Entfernt',
			'workspace.projectMemberAlreadyRemovedToast' => 'Dieser Nutzer ist kein Projektmitglied mehr',
			'workspace.projectMemberTransferTitle' => ({required Object name}) => 'Projektleitung an ${name} übertragen',
			'workspace.projectMemberTransferDesc' => 'Nach der Übertragung erhält die andere Person die vollständige Verwaltung dieses Projekts',
			'workspace.projectMemberTransferConfirm' => 'Übertragung bestätigen',
			'workspace.projectMemberTransferDoneToast' => 'Projektleitung übertragen',
			'workspace.projectMilestonesTitle' => 'Meilensteine',
			'workspace.projectMilestoneEmptyTitle' => 'Noch keine Meilensteine',
			'workspace.projectMilestoneEmptySubtitle' => 'Markieren Sie Schlüsselpunkte des Projekts mit Meilensteinen (Geplant → Erreicht, eine Richtung)',
			'workspace.projectMilestoneCreateTitle' => 'Neuer Meilenstein',
			'workspace.projectMilestoneNameLabel' => 'Name',
			'workspace.projectMilestoneNameRequired' => 'Meilensteinname darf nicht leer sein',
			'workspace.projectMilestoneDueDateLabel' => 'Fälligkeitsdatum (YYYY-MM-DD, optional)',
			'workspace.projectMilestoneDueDateInvalid' => 'Datumsformat sollte YYYY-MM-DD sein',
			'workspace.projectMilestoneCreateSubmit' => 'Erstellen',
			'workspace.projectMilestoneCreatedToast' => 'Meilenstein erstellt',
			'workspace.projectMilestoneFilterAll' => 'Alle',
			'workspace.projectMilestoneFilterPlanned' => 'Geplant',
			'workspace.projectMilestoneFilterReached' => 'Erreicht',
			'workspace.projectMilestoneReach' => 'Als erreicht markieren',
			'workspace.projectMilestoneReachedToast' => 'Meilenstein erreicht',
			'workspace.projectMilestoneAlreadyReachedToast' => 'Meilenstein bereits erreicht',
			'workspace.projectMilestoneReachedHint' => 'Erreicht (nicht zurücksetzbar)',
			'workspace.projectMilestoneDueLabel' => 'Fällig',
			'workspace.projectChannelsTitle' => 'Projektkanäle',
			'workspace.projectChannelEmptyTitle' => 'Noch keine verknüpften Kanäle',
			'workspace.projectChannelEmptySubtitle' => 'Nach der Verknüpfung eines Arbeitsbereich-Kanals werden dessen angepinnte Inhalte und neueste Beiträge in dieses Projekt gebündelt',
			'workspace.projectChannelLinkTitle' => 'Zu verknüpfenden Kanal auswählen',
			'workspace.projectChannelNoCandidate' => 'Keine Kanäle zum Verknüpfen verfügbar',
			'workspace.projectChannelLinkedToast' => 'Kanal verknüpft',
			'workspace.projectChannelLinkExistingToast' => 'Kanal bereits verknüpft',
			'workspace.projectChannelUnlinkTitle' => ({required Object name}) => '„${name}“ entkoppeln',
			'workspace.projectChannelUnlinkDesc' => 'Nach dem Entkoppeln werden Inhalte dieses Kanals nicht mehr in das Projekt gebündelt',
			'workspace.projectChannelUnlinkSubmit' => 'Entkoppeln',
			'workspace.projectChannelUnlinkedToast' => 'Entkoppelt',
			'workspace.projectInsightsTabPinned' => 'Angepinnte Nachrichten',
			'workspace.projectInsightsTabResources' => 'Ressourcenlinks',
			'workspace.projectInsightsTabActivity' => 'Projektaktivität',
			'workspace.projectInsightsTabPosts' => 'Bezogene Beiträge',
			'workspace.projectInsightsPinnedEmpty' => 'Keine angepinnten Inhalte im verknüpften Kanal',
			'workspace.projectInsightsResourcesEmpty' => 'Noch keine Ressourcenlinks im Projekt',
			'workspace.projectInsightsActivityEmpty' => 'Noch keine Projektaktivität',
			'workspace.projectInsightsPostsEmpty' => 'Keine Beiträge im verknüpften Kanal',
			'workspace.projectInsightsPostAuthor' => ({required Object name}) => 'Von ${name} veröffentlicht',
			'workspace.advancedFeatures' => 'Erweiterte Funktionen',
			'workspace.assistantEntry' => 'KI-Assistent',
			'workspace.comingSoon' => 'Demnächst',
			'workspace.createOrJoinEnterprise' => 'Organisation erstellen oder beitreten',
			'workspace.featureComingSoon' => 'Funktion in Entwicklung',
			'workspace.filterDm' => 'Direktnachrichten',
			'workspace.filterEdit' => 'Bearbeiten',
			'workspace.filterEmptyTitle' => 'Keine passenden Unterhaltungen',
			'workspace.filterExternalChat' => 'Externe Chats',
			'workspace.filterFlagged' => 'Markiert',
			'workspace.filterInternalChat' => 'Interne Chats',
			'workspace.filterMentions' => 'Erwähnungen',
			'workspace.filterUnread' => 'Ungelesen',
			'workspace.filterUnreadEmptyTitle' => 'Keine ungelesenen Unterhaltungen',
			'workspace.myCard' => 'Meine Karte',
			'workspace.orgUnverified' => 'Unverifiziert',
			'workspace.recordFaceChat' => 'Face-to-Face-Chat protokollieren',
			'workspace.smartSummary' => 'Intelligente Zusammenfassung',
			'workspace.tabSchedule' => 'Terminplan',
			'workspace.tabTodo' => 'Aufgaben',
			'workspace.takeABreak' => 'Kurze Pause machen',
			'workspace.todoEmptyTitle' => 'Keine Aufgaben',
			_ => null,
		};
	}
}
