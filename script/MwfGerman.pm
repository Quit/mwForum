#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright © 1999-2013 Markus Wichitill
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#------------------------------------------------------------------------------

package MwfGerman;
use utf8;
use strict;
our $VERSION = "2.29.0";
our $lng = {};

#------------------------------------------------------------------------------

# Default to English for missing strings
require MwfEnglish;
%$lng = %$MwfEnglish::lng;

#------------------------------------------------------------------------------

# Language module meta information
$lng->{author}       = "Markus Wichitill";

#------------------------------------------------------------------------------

# Common strings
$lng->{comUp}        = "Hoch";
$lng->{comUpTT}      = "Zu höherer Ebene gehen";
$lng->{comPgPrev}    = "Zurück";
$lng->{comPgPrevTT}  = "Zu vorheriger Seite gehen";
$lng->{comPgNext}    = "Vor";
$lng->{comPgNextTT}  = "Zu nächster Seite gehen";
$lng->{comBoardList} = "Forum";
$lng->{comNew}       = "N";
$lng->{comNewTT}     = "Neu";
$lng->{comOld}       = "-";
$lng->{comOldTT}     = "Alt";
$lng->{comNewUnrd}   = "N/U";
$lng->{comNewUnrdTT} = "Neu/Ungelesen";
$lng->{comNewRead}   = "N/-";
$lng->{comNewReadTT} = "Neu/Gelesen";
$lng->{comOldUnrd}   = "-/U";
$lng->{comOldUnrdTT} = "Alt/Ungelesen";
$lng->{comOldRead}   = "-/-";
$lng->{comOldReadTT} = "Alt/Gelesen";
$lng->{comAnswer}    = "B";
$lng->{comAnswerTT}  = "Beantwortet";
$lng->{comShowNew}   = "Neues";
$lng->{comShowNewTT} = "Neue Nachrichten anzeigen";
$lng->{comShowUnr}   = "Ungelesenes";
$lng->{comShowUnrTT} = "Ungelesene Nachrichten anzeigen";
$lng->{comFeeds}     = "Feeds";
$lng->{comFeedsTT}   = "Atom/RSS-Feeds anzeigen";
$lng->{comCaptcha}   = "Bitte tippen Sie die sechs Buchstaben vom Anti-Spam-Bild ab";

# Header
$lng->{hdrForum}     = "Forum";
$lng->{hdrForumTT}   = "Forums-Startseite";
$lng->{hdrHomeTT}    = "Zum Forum gehörige Homepage";
$lng->{hdrProfile}   = "Profil";
$lng->{hdrProfileTT} = "Benutzerprofil ändern";
$lng->{hdrOptions}   = "Optionen";
$lng->{hdrOptionsTT} = "Benutzeroptionen ändern";
$lng->{hdrHelp}      = "Hilfe";
$lng->{hdrHelpTT}    = "Hilfe und FAQ";
$lng->{hdrSearch}    = "Suche";
$lng->{hdrSearchTT}  = "Nachrichten durchsuchen";
$lng->{hdrChat}      = "Chat";
$lng->{hdrChatTT}    = "Chat-Nachrichten lesen und schreiben";
$lng->{hdrMsgs}      = "Nachrichten";
$lng->{hdrMsgsTT}    = "Private Nachrichten lesen und schreiben";
$lng->{hdrLogin}     = "Anmelden";
$lng->{hdrLoginTT}   = "Mit Benutzername und Passwort anmelden";
$lng->{hdrLogout}    = "Abmelden";
$lng->{hdrLogoutTT}  = "Abmelden";
$lng->{hdrReg}       = "Registrieren";
$lng->{hdrRegTT}     = "Benutzerkonto registrieren";
$lng->{hdrOpenId}    = "OpenID";
$lng->{hdrOpenIdTT}  = "Mit OpenID anmelden";
$lng->{hdrNoLogin}   = "Nicht angemeldet";
$lng->{hdrWelcome}   = "Angemeldet als";
$lng->{hdrArchive}   = "Archiv";

# Forum page
$lng->{frmTitle}     = "Forum";
$lng->{frmMarkOld}   = "Alles alt";
$lng->{frmMarkOldTT} = "Alle Nachrichten als alt markieren";
$lng->{frmMarkRd}    = "Alles gelesen";
$lng->{frmMarkRdTT}  = "Alle Nachrichten als gelesen markieren";
$lng->{frmUsers}     = "Benutzer";
$lng->{frmUsersTT}   = "Benutzerliste anzeigen";
$lng->{frmAttach}    = "Dateien";
$lng->{frmAttachTT}  = "Dateianhangsliste anzeigen";
$lng->{frmInfo}      = "Info";
$lng->{frmInfoTT}    = "Foruminfo anzeigen";
$lng->{frmNotTtl}    = "Benachrichtigungen";
$lng->{frmNotDelB}   = "Benachrichtigungen entfernen";
$lng->{frmCtgCollap} = "Kategorie zusammenklappen";
$lng->{frmCtgExpand} = "Kategorie expandieren";
$lng->{frmPosts}     = "Nachrichten";
$lng->{frmLastPost}  = "Neueste";
$lng->{frmRegOnly}   = "Nur für registrierte Benutzer";
$lng->{frmMbrOnly}   = "Nur für Brettmitglieder";
$lng->{frmNew}       = "neu";
$lng->{frmNoBoards}  = "Keine sichtbaren Bretter.";
$lng->{frmStats}     = "Statistiken";
$lng->{frmOnlUsr}    = "Online";
$lng->{frmOnlUsrTT}  = "Benutzer online während der letzten 5 Minuten";
$lng->{frmNewUsr}    = "Neu";
$lng->{frmNewUsrTT}  = "Benutzer registriert während der letzten 5 Tage";
$lng->{frmBdayUsr}   = "Geburtstag";
$lng->{frmBdayUsrTT} = "Benutzer die heute Geburtstag haben";

# Forum info page
$lng->{fifTitle}     = "Forum";
$lng->{fifBrowsers}  = "Browser";
$lng->{fifCountries} = "Länder";
$lng->{fifActivity}  = "Aktivität";
$lng->{fifGenTtl}    = "Allgemeine Info";
$lng->{fifGenAdmEml} = "Emailadresse";
$lng->{fifGenAdmins} = "Administratoren";
$lng->{fifGenTZone}  = "Zeitzone";
$lng->{fifGenVer}    = "Forumsversion";
$lng->{fifGenLang}   = "Sprachen";
$lng->{fifStsTtl}    = "Statistik";
$lng->{fifStsUsrNum} = "Benutzer";
$lng->{fifStsTpcNum} = "Themen";
$lng->{fifStsPstNum} = "Nachrichten";

# Forum browsers page
$lng->{uasTitle}     = "Benutzeragenten";
$lng->{uasUsersT}    = "Ausgewertet werden [[users]] Benutzer, die während der letzten [[days]] Tage eingeloggt waren.";
$lng->{uasChartTtl}  = "Graphen";
$lng->{uasUaTtl}     = "Browser";
$lng->{uasOsTtl}     = "Betriebssysteme";

# User countries page
$lng->{ucoTitle}     = "Benutzerländer";
$lng->{ucoMapTtl}    = "Karte";
$lng->{ucoCntryTtl}  = "Länder";

# Forum activity page
$lng->{actTitle}     = "Forumsaktivität";
$lng->{actPstDayT}   = "Horizontale Achse: ein Pixel pro Tag, vertikale Achse: ein Pixel pro Nachricht. Nur existierende Nachrichten werden gezählt.";
$lng->{actPstDayTtl} = "Nachrichten pro Tag";
$lng->{actPstYrTtl}  = "Nachrichten pro Jahr";

# New/unread overview page
$lng->{ovwTitleNew}  = "Neue Nachrichten";
$lng->{ovwTitleUnr}  = "Ungelesene Nachrichten";
$lng->{ovwMore}      = "Mehr";
$lng->{ovwMoreTT}    = "Mehr Nachrichten auf der nächsten Seite anzeigen";
$lng->{ovwRefresh}   = "Aktualisieren";
$lng->{ovwRefreshTT} = "Seite aktualisieren";
$lng->{ovwMarkOld}   = "Alles alt";
$lng->{ovwMarkOldTT} = "Alle Nachrichten als alt markieren";
$lng->{ovwMarkRd}    = "Alles gelesen";
$lng->{ovwMarkRdTT}  = "Alle Nachrichten als gelesen markieren";
$lng->{ovwFltTpc}    = "Filter";
$lng->{ovwFltTpcTT}  = "Nur dieses Thema zeigen";
$lng->{ovwEmpty}     = "Keine sichtbaren Nachrichten vorhanden.";
$lng->{ovwMaxCutoff} = "Thema hat zu viele Nachrichten, überspringe den Rest.";

# Board page
$lng->{brdTitle}     = "Brett";
$lng->{brdNewTpc}    = "Schreiben";
$lng->{brdNewTpcTT}  = "Neues Thema schreiben";
$lng->{brdInfo}      = "Info";
$lng->{brdInfoTT}    = "Brettinfo anzeigen";
$lng->{brdMarkRd}    = "Alles gelesen";
$lng->{brdMarkRdTT}  = "Alle Nachrichten des Brettes als gelesen markieren";
$lng->{brdTopic}     = "Thema";
$lng->{brdPoster}    = "Benutzer";
$lng->{brdPosts}     = "Nachrichten";
$lng->{brdLastPost}  = "Neueste";
$lng->{brdLocked}    = "L";
$lng->{brdLockedTT}  = "Gesperrt";
$lng->{brdInvis}     = "I";
$lng->{brdInvisTT}   = "Unsichtbar";
$lng->{brdPoll}      = "P";
$lng->{brdPollTT}    = "Umfrage";
$lng->{brdNew}       = "neu";
$lng->{brdAdmin}     = "Administration";
$lng->{brdAdmRep}    = "Meldungen";
$lng->{brdAdmRepTT}  = "Meldungen von Nachrichten anzeigen";
$lng->{brdAdmGrp}    = "Gruppen";
$lng->{brdAdmGrpTT}  = "Gruppenbefugnisse editieren";
$lng->{brdAdmSpl}    = "Aufteilen";
$lng->{brdAdmSplTT}  = "Massenweise Themen in andere Bretter verschieben";
$lng->{brdBoardFeed} = "Brett-Feed";

# Board info page
$lng->{bifTitle}     = "Brett";
$lng->{bifOptTtl}    = "Optionen";
$lng->{bifOptDesc}   = "Beschreibung";
$lng->{bifOptLock}   = "Sperrzeit";
$lng->{bifOptLockT}  = "Tage nach letzter Nachricht werden Themen gesperrt";
$lng->{bifOptExp}    = "Haltezeit";
$lng->{bifOptExpT}   = "Tage nach letzter Nachricht werden Themen gelöscht";
$lng->{bifOptAttc}   = "Anhänge";
$lng->{bifOptAttcY}  = "Dateianhänge sind aktiviert";
$lng->{bifOptAttcN}  = "Dateianhänge sind nicht aktiviert";
$lng->{bifOptAprv}   = "Moderation";
$lng->{bifOptAprvY}  = "Nachrichten müssen bestätigt werden, um sichtbar zu sein";
$lng->{bifOptAprvN}  = "Nachrichten müssen nicht bestätigt werden, um sichtbar zu sein";
$lng->{bifOptPriv}   = "Lesezugriff";
$lng->{bifOptPriv0}  = "Alle Benutzer können das Brett sehen";
$lng->{bifOptPriv1}  = "Nur Admins/Moderatoren/Mitglieder können das Brett sehen";
$lng->{bifOptPriv2}  = "Nur registrierte Benutzer können das Brett sehen";
$lng->{bifOptAnnc}   = "Schreibzugriff";
$lng->{bifOptAnnc0}  = "Alle Benutzer können schreiben";
$lng->{bifOptAnnc1}  = "Nur Admins/Moderatoren/Mitglieder können schreiben";
$lng->{bifOptAnnc2}  = "Admins/Moderatoren/Mitglieder können neue Themen starten, alle können antworten";
$lng->{bifOptUnrg}   = "Registrierung";
$lng->{bifOptUnrgY}  = "Schreiben ist auch ohne Registrierung möglich";
$lng->{bifOptUnrgN}  = "Schreiben ist nur mit Registrierung möglich";
$lng->{bifOptFlat}   = "Struktur";
$lng->{bifOptFlatY}  = "Nachrichten werden sequentiell angeordnet";
$lng->{bifOptFlatN}  = "Nachrichten werden in einer Baumstruktur angeordnet";
$lng->{bifAdmsTtl}   = "Moderatorgruppen";
$lng->{bifMbrsTtl}   = "Mitgliedsgruppen";
$lng->{bifStatTtl}   = "Statistik";
$lng->{bifStatTPst}  = "Anzahl Nachrichten";
$lng->{bifStatLPst}  = "Neueste Nachricht";

# Topic page
$lng->{tpcTitle}     = "Thema";
$lng->{tpcTpcRepl}   = "Schreiben";
$lng->{tpcTpcReplTT} = "Das Thema allgemein betreffende Nachricht schreiben";
$lng->{tpcTag}       = "Taggen";
$lng->{tpcTagTT}     = "Thema-Tag setzen";
$lng->{tpcSubs}      = "Abonnieren";
$lng->{tpcSubsTT}    = "Thema per Email abonnieren";
$lng->{tpcPolAdd}    = "Umfrage";
$lng->{tpcPolAddTT}  = "Umfrage hinzufügen";
$lng->{tpcPolDel}    = "Löschen";
$lng->{tpcPolDelTT}  = "Umfrage löschen";
$lng->{tpcPolLock}   = "Beenden";
$lng->{tpcPolLockTT} = "Umfrage beenden (irreversibel)";
$lng->{tpcPolTtl}    = "Umfrage";
$lng->{tpcPolLocked} = "(beendet)";
$lng->{tpcPolVote}   = "Abstimmen";
$lng->{tpcPolShwRes} = "Ergebnis anzeigen";
$lng->{tpcHidTtl}    = "Unsichtbare Nachricht";
$lng->{tpcHidIgnore} = "(ignoriert) ";
$lng->{tpcHidUnappr} = "(unbestätigt) ";
$lng->{tpcLike}      = "Gut";
$lng->{tpcLikeTT}    = "Nachricht als gut bewerten";
$lng->{tpcUnlike}    = "Ungut";
$lng->{tpcUnlikeTT}  = "Nachricht nicht mehr als gut bewerten";
$lng->{tpcApprv}     = "Bestätigen";
$lng->{tpcApprvTT}   = "Nachricht für alle sichtbar machen";
$lng->{tpcLock}      = "Sperren";
$lng->{tpcLockTT}    = "Nachricht sperren um Editieren und Antworten zu verhindern";
$lng->{tpcUnlock}    = "Entsperren";
$lng->{tpcUnlockTT}  = "Nachricht entsperren um Editieren und Antworten zu ermöglichen";
$lng->{tpcReport}    = "Hinweisen";
$lng->{tpcReportTT}  = "Benutzer oder Moderatoren auf Nachricht hinweisen";
$lng->{tpcBranch}    = "Zweig";
$lng->{tpcBranchTT}  = "Zweig umwandeln/verschieben/sperren/löschen";
$lng->{tpcEdit}      = "Ändern";
$lng->{tpcEditTT}    = "Nachricht editieren";
$lng->{tpcDelete}    = "Löschen";
$lng->{tpcDeleteTT}  = "Nachricht löschen";
$lng->{tpcAttach}    = "Anhängen";
$lng->{tpcAttachTT}  = "Dateianhänge hochladen und löschen";
$lng->{tpcReply}     = "Antworten";
$lng->{tpcReplyTT}   = "Auf Nachricht antworten";
$lng->{tpcQuote}     = "Zitieren";
$lng->{tpcQuoteTT}   = "Auf Nachricht antworten mit Zitat";
$lng->{tpcBrnCollap} = "Zweig zusammenklappen";
$lng->{tpcBrnExpand} = "Zweig expandieren";
$lng->{tpcNxtPst}    = "Nächste";
$lng->{tpcNxtPstTT}  = "Zu nächster neuer oder ungelesener Nachricht gehen";
$lng->{tpcParent}    = "Basis";
$lng->{tpcParentTT}  = "Zu beantworteter Nachricht gehen";
$lng->{tpcLockd}     = "L";
$lng->{tpcLockdTT}   = "Gesperrt";
$lng->{tpcInvis}     = "I";
$lng->{tpcInvisTT}   = "Unsichtbar";
$lng->{tpcAttText}   = "Dateianhang:";
$lng->{tpcAdmStik}   = "Fixieren";
$lng->{tpcAdmUnstik} = "Defixieren";
$lng->{tpcAdmLock}   = "Sperren";
$lng->{tpcAdmUnlock} = "Entsperren";
$lng->{tpcAdmMove}   = "Verschieben";
$lng->{tpcAdmMerge}  = "Zusammenlegen";
$lng->{tpcAdmDelete} = "Löschen";
$lng->{tpcBy}        = "Von";
$lng->{tpcOn}        = "Datum";
$lng->{tpcEdited}    = "Editiert";
$lng->{tpcLikes}     = "Gut";
$lng->{tpcLocked}    = "(gesperrt)";

# Topic subscription page
$lng->{tsbTitle}     = "Thema";
$lng->{tsbSubTtl}    = "Thema abonnieren";
$lng->{tsbSubT2}     = "Sofort-Abonnements senden Ihnen neue Nachrichten im gewählten Thema sofort per Email zu. Sammel-Abonnements senden die Nachrichten gesammelt in regelmäßigen Abständen (üblicherweise täglich).";
$lng->{tsbInstant}   = "Sofort-Abonnement";
$lng->{tsbDigest}    = "Sammel-Abonnement";
$lng->{tsbSubB}      = "Abonnieren";
$lng->{tsbUnsubTtl}  = "Thema abbestellen";
$lng->{tsbUnsubB}    = "Abbestellen";

# Add poll page
$lng->{aplTitle}     = "Umfrage hinzufügen";
$lng->{aplPollTitle} = "Umfragetitel bzw. Frage";
$lng->{aplPollOpts}  = "Optionen (eine Option pro Zeile, max. 20 Optionen, max. 60 Zeichen pro Option, keine Formatierung)";
$lng->{aplPollMulti} = "Mehrfaches Abstimmen für verschiedene Optionen zulassen";
$lng->{aplPollNote}  = "Man kann Umfragen nicht editieren und man kann sie nicht mehr löschen, wenn bereits jemand abgestimmt hat. Daher bitte den Titel und die Optionen vor dem Hinzufügen gründlich überprüfen.";
$lng->{aplPollAddB}  = "Hinzufügen";

# Add report page
$lng->{arpTitle}     = "Nachricht";
$lng->{arpPngTtl}    = "Benutzer auf Nachricht hinweisen";
$lng->{arpPngT}      = "Sendet einen Hinweis auf diese Nachricht an die Benachrichtigungsliste eines Benutzers und optional per Email.";
$lng->{arpPngUser}   = "Empfänger";
$lng->{arpPngEmail}  = "Auch per Email senden";
$lng->{arpPngB}      = "Hinweisen";
$lng->{arpPngMlSbPf} = "Hinweis von";
$lng->{arpPngMlT}    = "Dies ist eine Hinweis-Benachrichtigung der Forumssoftware.\nBitte antworten Sie nicht auf diese Email.";
$lng->{arpRepTtl}    = "Nachricht den Moderatoren melden";
$lng->{arpRepT}      = "Falls eine Nachricht gegen Gesetze oder die Regeln des Forums verstößt, kann sie den Moderatoren und Administratoren gemeldet werden.";
$lng->{arpRepYarly}  = "Ich möchte die Nachricht melden, und nicht etwa antworten";
$lng->{arpRepReason} = "Begründung";
$lng->{arpRepB}      = "Melden";
$lng->{arpThrTtl}    = "Baumstruktur-Belehrung senden";
$lng->{arpThrT}      = "Falls ein Benutzer auf die falsche Nachricht geantwortet hat, kann hiermit eine Benachrichtigung gesendet werden, die den Benutzer bittet, auf die richtigen Nachrichten zu antworten, um die Baumstruktur der Themen zu bewahren. Dies ist im allgemeinen öffentlichen Hinweisnachrichten vorzuziehen. Kann nur von Admins/Mods, innerhalb von 24 Stunden und nur einmal pro Empfänger genutzt werden, um eine Überflutung zu vermeiden.";
$lng->{arpThrB}      = "Belehren";

# Report list page
$lng->{repTitle}     = "Meldungen";
$lng->{repBy}        = "Meldung von";
$lng->{repTopic}     = "Thema";
$lng->{repPoster}    = "Benutzer";
$lng->{repPosted}    = "Datum";
$lng->{repDeleteB}   = "Meldung entfernen";
$lng->{repEmpty}     = "Keine Meldungen vorhanden.";

# Tag button bar
$lng->{tbbMod}       = "Mod";
$lng->{tbbBold}      = "Fett";
$lng->{tbbItalic}    = "Kursiv";
$lng->{tbbTeletype}  = "Nicht proportional";
$lng->{tbbImage}     = "Bild";
$lng->{tbbVideo}     = "Video";
$lng->{tbbCustom}    = "Speziell";
$lng->{tbbInsSnip}   = "Text einfügen";

# Reply page
$lng->{rplTitle}     = "Thema";
$lng->{rplTopicTtl}  = "Das Thema allgemein betreffende Nachricht schreiben";
$lng->{rplReplyTtl}  = "Antwort schreiben";
$lng->{rplReplyT}    = "Dieses Brett hat eine Baumstruktur. Bitte benutzen Sie den \"Antworten\"-Knopf der Nachricht, auf die Sie Sich beziehen, nicht einfach irgendeinen. Wenn Sie etwas zum Thema allgemein sagen wollen, benutzen Sie bitte den \"Schreiben\"-Knopf ganz oben oder unten auf der Seite.";
$lng->{rplReplyName} = "Name";
$lng->{rplReplyIRaw} = "Rohtext einfügen";
$lng->{rplReplyRaw}  = "Rohtext (z.B. Quellcode)";
$lng->{rplReplyResp} = "Auf Nachricht von";
$lng->{rplReplyB}    = "Schreiben";
$lng->{rplReplyPrvB} = "Vorschau";
$lng->{rplPrvTtl}    = "Vorschau";
$lng->{rplEmailSbPf} = "Antwort von";
$lng->{rplEmailT2}   = "Dies ist eine Antwort-Benachrichtigung der Forumssoftware.\nBitte antworten Sie nicht auf diese Email.";
$lng->{rplAgeOrly}   = "Die Nachricht, auf die Sie antworten wollen, ist bereits [[age]] Tage alt. Sind Sie sicher, dass Sie wirklich auf eine so alte Nachricht antworten wollen?";
$lng->{rplAgeYarly}  = "Ja, ich habe einen guten Grund dafür";

# New topic page
$lng->{ntpTitle}     = "Brett";
$lng->{ntpTpcTtl}    = "Neues Thema schreiben";
$lng->{ntpTpcName}   = "Name";
$lng->{ntpTpcSbj}    = "Betreff";
$lng->{ntpTpcIRaw}   = "Rohtext einfügen";
$lng->{ntpTpcRaw}    = "Rohtext (z.B. Quellcode)";
$lng->{ntpTpcNtfy}   = "Antwortbenachrichtigungen empfangen";
$lng->{ntpTpcB}      = "Schreiben";
$lng->{ntpTpcPrvB}   = "Vorschau";
$lng->{ntpPrvTtl}    = "Vorschau";

# Post edit page
$lng->{eptTitle}     = "Nachricht";
$lng->{eptEditTtl}   = "Nachricht editieren";
$lng->{eptEditSbj}   = "Betreff";
$lng->{eptEditIRaw}  = "Rohtext einfügen";
$lng->{eptEditRaw}   = "Rohtext (z.B. Quellcode)";
$lng->{eptEditB}     = "Ändern";
$lng->{eptEditPrvB}  = "Vorschau";
$lng->{eptPrvTtl}    = "Vorschau";
$lng->{eptDeleted}   = "[gelöscht]";

# Post attachments page
$lng->{attTitle}     = "Dateianhänge";
$lng->{attDelAll}    = "Alle Löschen";
$lng->{attDelAllTT}  = "Alle Dateianhänge löschen";
$lng->{attDropNote}  = "Sie können Dateien auch durch Drag &amp; Drop auf das Formular hochladen.";
$lng->{attGoPostT}   = "Das Aufwärtspfeil-Icon bringt Sie zurück zur Nachricht.";
$lng->{attUplTtl}    = "Hochladen";
$lng->{attUplFiles}  = "Datei(en) (max. Dateigröße [[size]])";
$lng->{attUplCapt}   = "Beschriftung";
$lng->{attUplEmbed}  = "Einbetten (nur JPG, PNG und GIF-Bilder)";
$lng->{attUplB}      = "Hochladen";
$lng->{attAttTtl}    = "Anhang";
$lng->{attAttDelB}   = "Löschen";
$lng->{attAttChgB}   = "Ändern";

# User info page
$lng->{uifTitle}     = "Benutzer";
$lng->{uifListPst}   = "Nachrichten";
$lng->{uifListPstTT} = "Öffentliche Nachrichten dieses Benutzers auflisten";
$lng->{uifMessage}   = "Nachricht senden";
$lng->{uifMessageTT} = "Private Nachricht an diesen Benutzer senden";
$lng->{uifIgnore}    = "Ignorieren";
$lng->{uifIgnoreTT}  = "Diesen Benutzer ignorieren";
$lng->{uifWatch}     = "Überwachen";
$lng->{uifWatchTT}   = "Diesen Benutzer überwachen";
$lng->{uifProfTtl}   = "Profil";
$lng->{uifProfUName} = "Benutzername";
$lng->{uifProfOName} = "Alte Namen";
$lng->{uifProfRName} = "Realname";
$lng->{uifProfBdate} = "Geburtstag";
$lng->{uifProfPage}  = "Website";
$lng->{uifProfOccup} = "Tätigkeit";
$lng->{uifProfHobby} = "Hobbies";
$lng->{uifProfLocat} = "Ort";
$lng->{uifProfGeoIp} = "Ort (IP-basiert)";
$lng->{uifProfIcq}   = "Email/Messenger";
$lng->{uifProfSig}   = "Signatur";
$lng->{uifProfBlurb} = "Sonstiges";
$lng->{uifProfAvat}  = "Avatar";
$lng->{uifBadges}    = "Abzeichen";
$lng->{uifGrpMbrTtl} = "Gruppen";
$lng->{uifBrdSubTtl} = "Brettabonnements";
$lng->{uifTpcSubTtl} = "Themenabonnements";
$lng->{uifStatTtl}   = "Statistik";
$lng->{uifStatRank}  = "Rang";
$lng->{uifStatPNum}  = "Nachrichten";
$lng->{uifStatPONum} = "geschrieben";
$lng->{uifStatPENum} = "vorhanden";
$lng->{uifStatRegTm} = "Registriert";
$lng->{uifStatLOTm}  = "Zuletzt online";
$lng->{uifStatLRTm}  = "Vorher online";
$lng->{uifStatLIp}   = "Letzte IP";
$lng->{uifMapTtl}    = "Karte";
$lng->{uifMapOthrMt} = "andere mögliche Orte";

# User list page
$lng->{uliTitle}     = "Benutzerliste";
$lng->{uliLfmTtl}    = "Listenformat";
$lng->{uliLfmSearch} = "Suche";
$lng->{uliLfmField}  = "Ansicht";
$lng->{uliLfmSort}   = "Sort.";
$lng->{uliLfmSrtNam} = "Benutzername";
$lng->{uliLfmSrtUid} = "Benutzer-ID";
$lng->{uliLfmSrtFld} = "Ansicht";
$lng->{uliLfmOrder}  = "Reihenf.";
$lng->{uliLfmOrdAsc} = "Aufst.";
$lng->{uliLfmOrdDsc} = "Abst.";
$lng->{uliLfmHide}   = "Leere verstecken";
$lng->{uliLfmListB}  = "Auflisten";
$lng->{uliLstName}   = "Benutzername";

# User login page
$lng->{lgiTitle}     = "Benutzer";
$lng->{lgiLoginTtl}  = "Anmelden";
$lng->{lgiLoginT}    = "Falls Sie noch kein Benutzerkonto besitzen, können Sie eines <a href='[[regUrl]]'>registrieren</a>. Falls Sie gerade ein Konto registriert haben, sollte das Passwort per Email kommen (kann im Spam-Ordner landen).";
$lng->{lgiLoginName} = "Benutzername (oder Emailadresse)";
$lng->{lgiLoginPwd}  = "Passwort";
$lng->{lgiLoginRmbr} = "Auf diesem Computer merken";
$lng->{lgiLoginB}    = "Anmelden";
$lng->{lgiFpwTtl}    = "Passwort vergessen";
$lng->{lgiFpwT}      = "Falls Sie Ihr Passwort verloren haben, können Sie Sich einen Anmeldungs-Ticket-Link an Ihre registrierte Emailadresse zusenden lassen.";
$lng->{lgiFpwEmail}  = "Emailadresse";
$lng->{lgiFpwB}      = "Zusenden";
$lng->{lgiFpwMlSbj}  = "Passwort vergessen";
$lng->{lgiFpwMlT}    = "Besuchen Sie bitte den folgenden Ticket-Link, um sich ohne Passwort anzumelden. Sie können dann ein neues Passwort eingeben.\n\nAus Sicherheitsgründen ist der Ticket-Link nur einmal und nur für eine begrenzte Zeit gültig. Außerdem gilt nur der zuletzt zugesandte Ticket-Link, falls Sie sich mehrere haben zuschicken lassen.";

# User OpenID login page
$lng->{oidTitle}     = "Benutzer";
$lng->{oidLoginTtl}  = "Mit OpenID anmelden";
$lng->{oidLoginUrl}  = "OpenID-URL";
$lng->{oidLoginRmbr} = "Auf diesem Computer merken";
$lng->{oidLoginB}    = "Anmelden";
$lng->{oidListTtl}   = "Akzeptierte OpenID-Provider";

# User registration page
$lng->{regTitle}     = "Benutzer";
$lng->{regRegTtl}    = "Konto registrieren";
$lng->{regRegT}      = "Falls Sie schon ein Konto besitzen, können Sie sich auf der <a href='[[logUrl]]'>Anmelden-Seite</a> anmelden oder ein verlorenes Passwort ersetzen lassen.";
$lng->{regRegName}   = "Benutzername";
$lng->{regRegEmail}  = "Emailadresse (Anmeldungs-Passwort wird an diese Adresse gesendet)";
$lng->{regRegEmailV} = "Emailadresse wiederholen";
$lng->{regRegPwd}    = "Passwort";
$lng->{regRegPwdFmt} = "min. 8 Zeichen";
$lng->{regRegPwdV}   = "Passwort wiederholen";
$lng->{regRegB}      = "Registrieren";
$lng->{regMailSubj}  = "Registrierung";
$lng->{regMailT}     = "Sie haben ein Forums-Benutzerkonto registriert.";
$lng->{regMailName}  = "Benutzername: ";
$lng->{regMailPwd}   = "Passwort: ";
$lng->{regMailT2}    = "Nachdem Sie Sich per Link oder manuell per Benutzername und Passwort im Forum angemeldet haben, ändern Sie bitte unter Optionen/Passwort das Passwort auf ein einprägsameres.";

# User options page
$lng->{uopTitle}     = "Benutzer";
$lng->{uopPasswd}    = "Passwort";
$lng->{uopPasswdTT}  = "Passwort ändern";
$lng->{uopName}      = "Name";
$lng->{uopNameTT}    = "Benutzername ändern";
$lng->{uopEmail}     = "Email";
$lng->{uopEmailTT}   = "Emailadresse ändern";
$lng->{uopGroups}    = "Gruppen";
$lng->{uopGroupsTT}  = "Gruppen beitreten oder verlassen";
$lng->{uopBoards}    = "Bretter";
$lng->{uopBoardsTT}  = "Brettoptionen einstellen";
$lng->{uopTopics}    = "Themen";
$lng->{uopTopicsTT}  = "Themenoptionen einstellen";
$lng->{uopAvatar}    = "Avatar";
$lng->{uopAvatarTT}  = "Avatarbild auswählen";
$lng->{uopBadges}    = "Abzeichen";
$lng->{uopBadgesTT}  = "Abzeichen auswählen";
$lng->{uopIgnore}    = "Ignorieren";
$lng->{uopIgnoreTT}  = "Andere Benutzer ignorieren";
$lng->{uopWatch}     = "Überwachen";
$lng->{uopWatchTT}   = "Überwachte Wörter und Benutzer verwalten";
$lng->{uopOpenPgp}   = "OpenPGP";
$lng->{uopOpenPgpTT} = "Emailverschlüsselungs-Optionen einstellen";
$lng->{uopInfo}      = "Info";
$lng->{uopInfoTT}    = "Benutzerinfo anzeigen";
$lng->{uopProfTtl}   = "Profil";
$lng->{uopProfRName} = "Realname";
$lng->{uopProfBdate} = "Geburtstag (JJJJ-MM-TT oder MM-TT)";
$lng->{uopProfPage}  = "Website";
$lng->{uopProfOccup} = "Tätigkeit";
$lng->{uopProfHobby} = "Hobbies";
$lng->{uopProfLocat} = "Ort";
$lng->{uopProfLocIn} = "[Einfügen]";
$lng->{uopProfIcq}   = "Email/Messenger";
$lng->{uopProfSig}   = "Signatur";
$lng->{uopProfSigLt} = "(max. 100 Zeichen auf 2 Zeilen)";
$lng->{uopProfBlurb} = "Sonstiges";
$lng->{uopOptTtl}    = "Optionen";
$lng->{uopPrefPrivc} = "Datenschutz (Online-Status und IP-basierte Ortsinfo verstecken, Infoseite nur reg. Benutzern anzeigen)";
$lng->{uopPrefNtMsg} = "Benachrichtigungen über Antworten und private Nachrichten auch per Email empfangen";
$lng->{uopPrefNt}    = "Benachrichtigungen über Antworten empfangen";
$lng->{uopDispLang}  = "Sprache";
$lng->{uopDispTimeZ} = "Zeitzone";
$lng->{uopDispTimeS} = "Server";
$lng->{uopDispStyle} = "Stil";
$lng->{uopDispFFace} = "Schriftart";
$lng->{uopDispFSize} = "Schriftgröße (in Pixeln, 0 = Standard)";
$lng->{uopDispIndnt} = "Einzug (1-10%, für Baumstruktur)";
$lng->{uopDispTpcPP} = "Themen pro Seite (0 = benutze erlaubtes Maximum)";
$lng->{uopDispPstPP} = "Nachrichten pro Seite (0 = benutze erlaubtes Maximum)";
$lng->{uopDispDescs} = "Brettbeschreibungen anzeigen";
$lng->{uopDispDeco}  = "Dekoration anzeigen (Benutzertitel, Abzeichen, Ränge, etc.)";
$lng->{uopDispAvas}  = "Avatare anzeigen";
$lng->{uopDispImgs}  = "Eingebettete Bilder und Videos anzeigen";
$lng->{uopDispSigs}  = "Signaturen anzeigen";
$lng->{uopDispColl}  = "Themenzweige ohne neue/ungel. Nachrichten zusammenklappen";
$lng->{uopSubmitB}   = "Ändern";

# User password page
$lng->{pwdTitle}     = "Benutzer";
$lng->{pwdChgTtl}    = "Passwort ändern";
$lng->{pwdChgT}      = "Benutzen Sie bitte niemals dasselbe Passwort für verschiedene Konten.";
$lng->{pwdChgPwd}    = "Passwort";
$lng->{pwdChgPwdFmt} = "min. 8 Zeichen";
$lng->{pwdChgPwdV}   = "Passwort wiederholen";
$lng->{pwdChgB}      = "Ändern";

# User name page
$lng->{namTitle}     = "Benutzer";
$lng->{namChgTtl}    = "Benutzername ändern";
$lng->{namChgT}      = "Da Umbenennung oft Konfusion verursacht, benutzen Sie diese Funktion bitte nur, wenn Sie dazu einen guten Grund haben (z.B. Korrektur der Schreibweise, Vereinheitlichung der Namen verschiedener Onlinekonten oder Änderung alberner Namen, denen Sie entwachsen sind).";
$lng->{namChgT2}     = "Sie können Sich noch <em>[[times]]</em> mal umbenennen.";
$lng->{namChgName}   = "Benutzername";
$lng->{namChgB}      = "Ändern";

# User email page
$lng->{emlTitle}     = "Benutzer";
$lng->{emlChgTtl}    = "Emailadresse";
$lng->{emlChgT}      = "Eine neue oder geänderte Emailadresse wird erst wirksam, wenn Sie auf die an diese Adresse gesendete Bestätigungsemail reagiert haben.";
$lng->{emlChgAddr}   = "Emailadresse";
$lng->{emlChgAddrV}  = "Emailadresse wiederholen";
$lng->{emlChgB}      = "Ändern";
$lng->{emlChgMlSubj} = "Emailadressen-Änderung";
$lng->{emlChgMlT}    = "Sie haben eine Änderung Ihrer Emailadresse beantragt. Um die Gültigkeit der neuen Adresse zu verifizieren, wird die Adresse erst geändert, wenn Sie den folgenden Ticket-Link besuchen:";

# User group options page
$lng->{ugrTitle}     = "Benutzer";
$lng->{ugrGrpStTtl}  = "Gruppenmitgliedschaft";
$lng->{ugrGrpStAdm}  = "Admin";
$lng->{ugrGrpStMbr}  = "Mitglied";
$lng->{ugrSubmitTtl} = "Gruppenmitgliedschaft ändern";
$lng->{ugrChgB}      = "Ändern";

# User board options page
$lng->{ubdTitle}     = "Benutzer";
$lng->{ubdSubsT2}    = "Sofort-Abonnements senden Ihnen neue Nachrichten im gewählten Brett sofort per Email zu. Sammel-Abonnements senden die Nachrichten gesammelt in regelmäßigen Abständen (üblicherweise täglich).";
$lng->{ubdBrdStTtl}  = "Brettoptionen";
$lng->{ubdBrdStSubs} = "Email-Abonnement";
$lng->{ubdBrdStInst} = "Sofort";
$lng->{ubdBrdStDig}  = "Sammel";
$lng->{ubdBrdStOff}  = "Aus";
$lng->{ubdBrdStHide} = "Verstecken";
$lng->{ubdSubmitTtl} = "Brettoptionen ändern";
$lng->{ubdChgB}      = "Ändern";

# User topic options page
$lng->{utpTitle}     = "Benutzer";
$lng->{utpTpcStTtl}  = "Themenoptionen";
$lng->{utpTpcStSubs} = "Email-Abonnement";
$lng->{ubdTpcStInst} = "Sofort";
$lng->{ubdTpcStDig}  = "Sammel";
$lng->{ubdTpcStOff}  = "Aus";
$lng->{utpEmpty}     = "Keine Themen mit aktivierten Optionen gefunden.";
$lng->{utpSubmitTtl} = "Themenoptionen ändern";
$lng->{utpChgB}      = "Ändern";

# Avatar page
$lng->{avaTitle}     = "Benutzer";
$lng->{avaUplTtl}    = "Eigener Avatar";
$lng->{avaUplImgExc} = "JPG/PNG/GIF-Bild (keine Animation, max. Dateigröße [[size]], genaue Dimensionen [[width]]x[[height]] Pixel)";
$lng->{avaUplImgRsz} = "JPG/PNG/GIF-Bild (keine Animation, max. Dateigröße [[size]])";
$lng->{avaUplUplB}   = "Hochladen";
$lng->{avaUplDelB}   = "Löschen";
$lng->{avaGalTtl}    = "Avatar-Galerie";
$lng->{avaGalSelB}   = "Auswählen";
$lng->{avaGalDelB}   = "Abwählen";
$lng->{avaGrvTtl}    = "Gravatar";
$lng->{avaGrvEmail}  = "Gravatar Emailadresse";
$lng->{avaGrvSelB}   = "Auswählen";
$lng->{avaGrvDelB}   = "Abwählen";

# User badges page
$lng->{bdgTitle}     = "Benutzer";
$lng->{bdgSelTtl}    = "Abzeichen";
$lng->{bdgSubmitTtl} = "Abzeichen auswählen";
$lng->{bdgSubmitB}   = "Auswählen";

# User ignore page
$lng->{uigTitle}     = "Benutzer";
$lng->{uigAddT}      = "Private Nachrichten von ignorierten Benutzern werden stillschweigend verworfen und öffentliche Nachrichten werden versteckt.";
$lng->{uigAddTtl}    = "Benutzer ignorieren";
$lng->{uigAddUser}   = "Benutzername";
$lng->{uigAddB}      = "Ignorieren";
$lng->{uigRemTtl}    = "Benutzer nicht mehr ignorieren";
$lng->{uigRemUser}   = "Benutzername";
$lng->{uigRemB}      = "Entfernen";

# Watch word/user page
$lng->{watTitle}     = "Benutzer";
$lng->{watWrdAddTtl} = "Überwachtes Wort hinzufügen";
$lng->{watWrdAddT}   = "Wenn ein überwachtes Wort in einer neuen Nachricht erwähnt wird, bekommen Sie eine Benachrichtigung.";
$lng->{watWrdAddWrd} = "Wort";
$lng->{watWrdAddB}   = "Hinzufügen";
$lng->{watWrdRemTtl} = "Überwachtes Wort entfernen";
$lng->{watWrdRemWrd} = "Wort";
$lng->{watWrdRemB}   = "Entfernen";
$lng->{watUsrAddTtl} = "Überwachten Benutzer hinzufügen";
$lng->{watUsrAddT}   = "Wenn ein überwachter Benutzer eine neue Nachricht schreibt, bekommen Sie eine Benachrichtigung.";
$lng->{watUsrAddUsr} = "Benutzername";
$lng->{watUsrAddB}   = "Hinzufügen";
$lng->{watUsrRemTtl} = "Überwachten Benutzer entfernen";
$lng->{watUsrRemUsr} = "Benutzername";
$lng->{watUsrRemB}   = "Entfernen";

# Group info page
$lng->{griTitle}     = "Gruppe";
$lng->{griMembers}   = "Mitglieder";
$lng->{griMbrTtl}    = "Mitglieder";
$lng->{griBrdAdmTtl} = "Moderator-Befugnisse";
$lng->{griBrdMbrTtl} = "Mitglieds-Befugnisse";

# Group members page
$lng->{grmTitle}     = "Gruppe";
$lng->{grmAddTtl}    = "Mitglieder hinzufügen";
$lng->{grmAddUser}   = "Benutzernamen (bei Texteingabe mit Semikolons trennen)";
$lng->{grmAddB}      = "Hinzufügen";
$lng->{grmRemTtl}    = "Mitglieder entfernen";
$lng->{grmRemUser}   = "Benutzername";
$lng->{grmRemB}      = "Entfernen";

# Board groups page
$lng->{bgrTitle}     = "Brett";
$lng->{bgrPermTtl}   = "Befugnisse";
$lng->{bgrModerator} = "Moderator";
$lng->{bgrMember}    = "Mitglied";
$lng->{bgrChangeTtl} = "Befugnisse ändern";
$lng->{bgrChangeB}   = "Ändern";

# Board split page
$lng->{bspTitle}     = "Brett";
$lng->{bspSplitTtl}  = "Brett aufteilen";
$lng->{bspSplitDest} = "Zielbrett";
$lng->{bspSplitB}    = "Aufteilen";

# Topic tag page
$lng->{ttgTitle}     = "Thema";
$lng->{ttgTagTtl}    = "Thema-Tag";
$lng->{ttgTagB}      = "Taggen";

# Topic move page
$lng->{mvtTitle}     = "Thema";
$lng->{mvtMovTtl}    = "Thema verschieben";
$lng->{mvtMovDest}   = "Zielbrett";
$lng->{mvtMovB}      = "Verschieben";

# Topic merge page
$lng->{mgtTitle}     = "Thema";
$lng->{mgtMrgTtl}    = "Themen zusammenlegen";
$lng->{mgtMrgDest}   = "Zielthema";
$lng->{mgtMrgDest2}  = "Alternative manuelle ID-Eingabe (für ältere Themen und Themen in anderen Brettern)";
$lng->{mgtMrgB}      = "Zusammenlegen";

# Branch page
$lng->{brnTitle}     = "Themenzweig";
$lng->{brnPromoTtl}  = "Zu Thema umwandeln";
$lng->{brnPromoSbj}  = "Betreff";
$lng->{brnPromoBrd}  = "Brett";
$lng->{brnPromoLink} = "Querverweis-Nachrichten einfügen";
$lng->{brnPromoB}    = "Umwandeln";
$lng->{brnProLnkBdy} = "Themenzweig verschoben";
$lng->{brnMoveTtl}   = "Verschieben";
$lng->{brnMovePrnt}  = "ID der übergeordneten Nachricht (kann in anderem Thema sein, 0 = verschiebe zu oberster Ebene in diesem Thema)";
$lng->{brnMoveB}     = "Verschieben";
$lng->{brnLockTtl}   = "Sperren";
$lng->{brnLockLckB}  = "Sperren";
$lng->{brnLockUnlB}  = "Entsperren";
$lng->{brnDeleteTtl} = "Löschen";
$lng->{brnDeleteB}   = "Löschen";

# Search page
$lng->{seaTitle}     = "Forum";
$lng->{seaTtl}       = "Suche";
$lng->{seaAdvOpt}    = "Mehr";
$lng->{seaBoard}     = "Brett";
$lng->{seaBoardAll}  = "Alle Bretter";
$lng->{seaWords}     = "Wörter";
$lng->{seaWordsFtsT} = "Benutzter Ausdruck für Volltextsuche: <em>[[expr]]</em>";
$lng->{seaUser}      = "Benutzer";
$lng->{seaMinAge}    = "Min. Alter";
$lng->{seaMaxAge}    = "Max. Alter";
$lng->{seaField}     = "Feld";
$lng->{seaFieldBody} = "Text";
$lng->{seaFieldRaw}  = "Rohtext";
$lng->{seaFieldSubj} = "Betreff";
$lng->{seaOrder}     = "Reihenf.";
$lng->{seaOrderAsc}  = "Alte zuerst";
$lng->{seaOrderDesc} = "Neue zuerst";
$lng->{seaB}         = "Suchen";
$lng->{seaGglTtl}    = "Suche - powered by Google&trade;";
$lng->{serTopic}     = "Thema";
$lng->{serNotFound}  = "Keine Treffer gefunden.";

# Help page
$lng->{hlpTitle}     = "Hilfe";
$lng->{hlpTxtTtl}    = "Begriffe und Funktionen";
$lng->{hlpFaqTtl}    = "Häufig gestellte Fragen";

# Message list page
$lng->{mslTitle}     = "Private Nachrichten";
$lng->{mslSend}      = "Senden";
$lng->{mslSendTT}    = "Private Nachricht an beliebigen Empfänger senden";
$lng->{mslExport}    = "Exportieren";
$lng->{mslExportTT}  = "Alle privaten Nachrichten in einer HTML-Datei exportieren";
$lng->{mslDelAll}    = "Löschen";
$lng->{mslDelAllTT}  = "Alle gelesenen und gesendeten Nachrichten löschen";
$lng->{mslInbox}     = "Eingang";
$lng->{mslOutbox}    = "Gesendet";
$lng->{mslFrom}      = "Absender";
$lng->{mslTo}        = "Empfänger";
$lng->{mslDate}      = "Datum";
$lng->{mslCommands}  = "Aktionen";
$lng->{mslDelete}    = "Löschen";
$lng->{mslNotFound}  = "Keine privaten Nachrichten vorhanden.";
$lng->{mslExpire}    = "Private Nachrichten werden nach [[days]] Tagen gelöscht.";

# Add message page
$lng->{msaTitle}     = "Private Nachricht";
$lng->{msaSendTtl}   = "Private Nachricht senden";
$lng->{msaSendRecv}  = "Empfänger";
$lng->{msaSendRecvM} = "Empfänger (bis zu [[maxRcv]] Namen mit Semikolon trennen)";
$lng->{msaSendSbj}   = "Betreff";
$lng->{msaSendTxt}   = "Text";
$lng->{msaSendB}     = "Absenden";
$lng->{msaSendPrvB}  = "Vorschau";
$lng->{msaPrvTtl}    = "Vorschau";
$lng->{msaRefTtl}    = "Antwort auf Nachricht von";
$lng->{msaEmailSbPf} = "Nachricht von";
$lng->{msaEmailTSbj} = "Betreff: ";
$lng->{msaEmailT2}   = "Dies ist eine Private Nachricht-Benachrichtigung der Forumssoftware.\nBitte antworten Sie nicht auf diese Email.";

# Message page
$lng->{mssTitle}     = "Private Nachricht";
$lng->{mssDelete}    = "Löschen";
$lng->{mssDeleteTT}  = "Nachricht löschen";
$lng->{mssReply}     = "Antworten";
$lng->{mssReplyTT}   = "Auf Nachricht antworten";
$lng->{mssQuote}     = "Zitieren";
$lng->{mssQuoteTT}   = "Auf Nachricht antworten mit Zitat";
$lng->{mssFrom}      = "Von";
$lng->{mssTo}        = "An";
$lng->{mssDate}      = "Datum";
$lng->{mssSubject}   = "Betreff";

# Chat page
$lng->{chtTitle}     = "Chat";
$lng->{chtRefresh}   = "Aktualisieren";
$lng->{chtRefreshTT} = "Seite aktualisieren";
$lng->{chtDelAll}    = "Alle Löschen";
$lng->{chtDelAllTT}  = "Alle Nachrichten löschen";
$lng->{chtAddTtl}    = "Nachricht schreiben";
$lng->{chtAddB}      = "Schreiben";
$lng->{chtMsgsTtl}   = "Nachrichten";

# Attachment list page
$lng->{aliTitle}     = "Dateianhangsliste";
$lng->{aliLfmTtl}    = "Suche und Format";
$lng->{aliLfmWords}  = "Wörter";
$lng->{aliLfmUser}   = "Benutzer";
$lng->{aliLfmBoard}  = "Brett";
$lng->{aliLfmField}  = "Feld";
$lng->{aliLfmFldFnm} = "Dateiname";
$lng->{aliLfmFldCpt} = "Beschriftung";
$lng->{aliLfmMinAge} = "Min. Alter";
$lng->{aliLfmMaxAge} = "Max. Alter";
$lng->{aliLfmOrder}  = "Reihenf.";
$lng->{aliLfmOrdAsc} = "Alte zuerst";
$lng->{aliLfmOrdDsc} = "Neue zuerst";
$lng->{aliLfmGall}   = "Galerie";
$lng->{aliLfmListB}  = "Auflisten";
$lng->{aliLstFile}   = "Dateiname";
$lng->{aliLstCapt}   = "Beschriftung";
$lng->{aliLstSize}   = "Größe";
$lng->{aliLstPost}   = "Nachricht";
$lng->{aliLstUser}   = "Benutzer";

# Feeds page
$lng->{fedTitle}     = "Feeds";
$lng->{fedAllBoards} = "Alle öffentlichen Bretter";

# Email subscriptions
$lng->{subSubjBrdIn} = "Sofort-Abo Brett";
$lng->{subSubjTpcIn} = "Sofort-Abo Thema";
$lng->{subSubjBrdDg} = "Sammel-Abo Brett";
$lng->{subSubjTpcDg} = "Sammel-Abo Thema";
$lng->{subNoReply}   = "Dies ist eine Abonnements-Email der Forumssoftware.\nBitte antworten Sie nicht auf diese Email.";
$lng->{subLink}      = "Link: ";
$lng->{subBoard}     = "Brett: ";
$lng->{subTopic}     = "Thema: ";
$lng->{subBy}        = "Schreiber: ";
$lng->{subOn}        = "Datum: ";
$lng->{subUnsubBrd}  = "Dieses Brett abbestellen:";
$lng->{subUnsubTpc}  = "Dieses Thema abbestellen:";

# Bounce detection
$lng->{bncWarning}   = "Warnung: entweder existiert Ihr Emailkonto nicht mehr, verweigert die Annahme von Emails, oder spammt mit automatischen Antworten. Bitte korrigieren Sie die Situation, da das Forum sonst evtl. die Zusendung von Emails an Sie einstellen muss.";

# Confirmation
$lng->{cnfTitle}     = "Bestätigung";
$lng->{cnfDelAllMsg} = "Wirklich alle gelesenen Nachrichten löschen?";
$lng->{cnfDelAllCht} = "Wirklich alle Chat-Nachrichten löschen?";
$lng->{cnfDelAllAtt} = "Wirklich alle Dateianhänge löschen?";
$lng->{cnfQuestion}  = "Wirklich";
$lng->{cnfQuestion2} = " löschen?";
$lng->{cnfTypeUser}  = "Benutzer";
$lng->{cnfTypeGroup} = "Gruppe";
$lng->{cnfTypeCateg} = "Kategorie";
$lng->{cnfTypeBoard} = "Brett";
$lng->{cnfTypeTopic} = "Thema";
$lng->{cnfTypePoll}  = "Umfrage";
$lng->{cnfTypePost}  = "Nachricht";
$lng->{cnfTypeMsg}   = "private Nachricht";
$lng->{cnfDeleteB}   = "Löschen";

# Notification messages
$lng->{notNotify}    = "Benutzer benachrichtigen (optional Grund angeben)";
$lng->{notReason}    = "Grund:";
$lng->{notMsgAdd}    = "[[usrNam]] hat eine private <a href='[[msgUrl]]'>Nachricht</a> gesendet.";
$lng->{notPstAdd}    = "[[usrNam]] hat auf eine <a href='[[pstUrl]]'>Nachricht</a> geantwortet.";
$lng->{notPstPng}    = "[[usrNam]] hat auf eine <a href='[[pstUrl]]'>Nachricht</a> hingewiesen.";
$lng->{notPstEdt}    = "Ein Moderator hat eine <a href='[[pstUrl]]'>Nachricht</a> geändert.";
$lng->{notPstDel}    = "Ein Moderator hat eine <a href='[[tpcUrl]]'>Nachricht</a> gelöscht.";
$lng->{notTpcMov}    = "Ein Moderator hat ein <a href='[[tpcUrl]]'>Thema</a> verschoben.";
$lng->{notTpcDel}    = "Ein Moderator hat ein Thema namens \"[[tpcSbj]]\" gelöscht.";
$lng->{notTpcMrg}    = "Ein Moderator hat ein Thema mit einem anderen <a href='[[tpcUrl]]'>Thema</a> zusammengelegt.";
$lng->{notEmlReg}    = "Willkommen, [[usrNam]]! Geben Sie bitte Ihre <a href='[[emlUrl]]'>Emailadresse</a> ein, um die emailbasierten Funktionen zu aktivieren.";
$lng->{notOidRen}    = "Da Ihnen kein kurzer Benutzername automatisch zugewiesen werden konnte, können Sie sich optional selbst <a href='[[namUrl]]'>umbenennen</a>.";
$lng->{notWatWrd}    = "Überwachtes Wort \"[[watWrd]]\" wurde in einer <a href='[[pstUrl]]'>Nachricht</a> erwähnt.";
$lng->{notWatUsr}    = "Überwachter Benutzer \"[[watUsr]]\" hat eine <a href='[[pstUrl]]'>Nachricht</a> geschrieben.";
$lng->{notThrStr}    = "Sie scheinen auf eine falsche <a href='[[pstUrl]]'>Nachricht</a> geantwortet zu haben. Bitte benutzen Sie genau den \"Antworten\"-Knopf der Nachricht, auf die Sie sich beziehen, und nicht einfach irgendeinen zufälligen Knopf. Dies ist wichtig, damit die Baumstruktur der Themen bewahrt bleibt, und damit Antwortbenachrichtigungen an die richtigen Empfänger gehen. Wenn Sie auf ein Thema allgemein antworten wollen, ohne sich auf eine spezifische Nachricht zu beziehen, benutzen Sie bitte den \"Schreiben\"-Knopf ganz oben oder unten auf der Seite.";

# Execution messages
$lng->{msgReplyPost} = "Nachricht eingetragen";
$lng->{msgNewPost}   = "Thema eingetragen";
$lng->{msgPstChange} = "Nachricht geändert";
$lng->{msgPstDel}    = "Nachricht gelöscht";
$lng->{msgPstTpcDel} = "Nachricht/Thema gelöscht";
$lng->{msgPstApprv}  = "Nachricht bestätigt";
$lng->{msgPstAttach} = "Dateianhang angefügt";
$lng->{msgPstDetach} = "Dateianhang gelöscht";
$lng->{msgPstAttChg} = "Dateianhang geändert";
$lng->{msgEmlChange} = "Bestätigungsemail gesendet";
$lng->{msgPrfChange} = "Profil geändert";
$lng->{msgOptChange} = "Optionen geändert";
$lng->{msgPwdChange} = "Passwort geändert";
$lng->{msgNamChange} = "Benutzername geändert";
$lng->{msgAvaChange} = "Avatar geändert";
$lng->{msgBdgChange} = "Abzeichen geändert";
$lng->{msgGrpChange} = "Gruppenmitgliedschaft geändert";
$lng->{msgBrdChange} = "Brettoptionen geändert";
$lng->{msgTpcChange} = "Themenoptionen geändert";
$lng->{msgAccntReg}  = "Konto registriert";
$lng->{msgAccntRegM} = "Konto registriert. Bitte warten Sie auf die Email mit Ihrem Passwort, bevor Sie sich anmelden. Die Email landet möglicherweise in Ihrem Spam-Ordner, und kann durch Anti-Spam-Maßnahmen verzögert ankommen.";
$lng->{msgMemberAdd} = "Mitglied(er) hinzugefügt";
$lng->{msgMemberRem} = "Mitglied(er) entfernt";
$lng->{msgTpcDelete} = "Thema gelöscht";
$lng->{msgTpcStik}   = "Thema fixiert";
$lng->{msgTpcUnstik} = "Thema defixiert";
$lng->{msgTpcLock}   = "Thema gesperrt";
$lng->{msgTpcUnlock} = "Thema entsperrt";
$lng->{msgTpcMove}   = "Thema verschoben";
$lng->{msgTpcMerge}  = "Themen zusammengelegt";
$lng->{msgBrnPromo}  = "Zweig befördert";
$lng->{msgBrnMove}   = "Zweig verschoben";
$lng->{msgBrnDelete} = "Zweig gelöscht";
$lng->{msgPstAddRep} = "Nachricht gemeldet";
$lng->{msgPstRemRep} = "Meldung gelöscht";
$lng->{msgMarkOld}   = "Nachrichten als alt markiert";
$lng->{msgMarkRead}  = "Nachrichten als gelesen markiert";
$lng->{msgPollAdd}   = "Umfrage hinzugefügt";
$lng->{msgPollDel}   = "Umfrage gelöscht";
$lng->{msgPollLock}  = "Umfrage beendet";
$lng->{msgPollVote}  = "Abgestimmt";
$lng->{msgMsgAdd}    = "Private Nachricht gesendet";
$lng->{msgMsgDel}    = "Private Nachricht(en) gelöscht";
$lng->{msgChatAdd}   = "Chat-Nachricht eingetragen";
$lng->{msgChatDel}   = "Chat-Nachricht(en) gelöscht";
$lng->{msgIgnoreAdd} = "Ignorierten Benutzer hinzugefügt";
$lng->{msgIgnoreRem} = "Ignorierten Benutzer entfernt";
$lng->{msgWatWrdAdd} = "Überwachtes Wort hinzugefügt";
$lng->{msgWatWrdRem} = "Überwachtes Wort entfernt";
$lng->{msgWatUsrAdd} = "Überwachten Benutzer hinzugefügt";
$lng->{msgWatUsrRem} = "Überwachten Benutzer entfernt";
$lng->{msgTksFgtPwd} = "Email zugesendet";
$lng->{msgTkaFgtPwd} = "Erfolgreich angemeldet. Sie können jetzt Ihr Passwort ändern.";
$lng->{msgTkaEmlChg} = "Emailadresse geändert";
$lng->{msgTpcTag}    = "Thema getaggt";
$lng->{msgTpcSub}    = "Thema abonniert";
$lng->{msgTpcUnsub}  = "Thema abbestellt";
$lng->{msgBrdUnsub}  = "Brett abbestellt";
$lng->{msgNotesDel}  = "Benachrichtigungen entfernt";
$lng->{msgPstLock}   = "Nachricht gesperrt";
$lng->{msgPstUnlock} = "Nachricht entsperrt";
$lng->{msgPstPing}   = "Hinweis gesendet";
$lng->{msgPstLike}   = "Nachricht als gut bewertet";
$lng->{msgPstUnlike} = "Nachricht nicht mehr als gut bewertet";

# Error messages
$lng->{errDefault}   = "[Fehlertext fehlt]";
$lng->{errParamMiss} = "Nötiger Parameter fehlt.";
$lng->{errCatNotFnd} = "Kategorie existiert nicht.";
$lng->{errBrdNotFnd} = "Brett existiert nicht.";
$lng->{errTpcNotFnd} = "Thema existiert nicht.";
$lng->{errPstNotFnd} = "Nachricht existiert nicht.";
$lng->{errAttNotFnd} = "Dateianhang existiert nicht.";
$lng->{errMsgNotFnd} = "Private Nachricht existiert nicht.";
$lng->{errUsrNotFnd} = "Benutzer existiert nicht.";
$lng->{errGrpNotFnd} = "Gruppe existiert nicht.";
$lng->{errTktNotFnd} = "Ticket existiert nicht. Tickets können nur einmal benutzt werden, verfallen nach zwei Tagen, und nur das zuletzt zugesandte Ticket ist gültig.";
$lng->{errUnsNotFnd} = "Abbestell-Code existiert nicht.";
$lng->{errUsrDel}    = "Benutzerkonto existiert nicht mehr.";
$lng->{errUsrFake}   = "Kein echtes Benutzerkonto.";
$lng->{errSubEmpty}  = "Betreff ist leer.";
$lng->{errBdyEmpty}  = "Nachrichtentext ist leer.";
$lng->{errNamEmpty}  = "Name ist leer.";
$lng->{errPwdEmpty}  = "Passwort ist leer.";
$lng->{errEmlEmpty}  = "Emailadresse ist leer.";
$lng->{errEmlInval}  = "Emailadresse ist ungültig.";
$lng->{errNamSize}   = "Name ist zu kurz oder zu lang.";
$lng->{errPwdSize}   = "Passwort muss min. 8 Zeichen lang sein.";
$lng->{errEmlSize}   = "Emailadresse ist zu kurz oder zu lang.";
$lng->{errNamChar}   = "Name enthält ungültige Zeichen.";
$lng->{errPwdChar}   = "Passwort enthält ungültige Zeichen.";
$lng->{errPwdWrong}  = "Passwort ist falsch.";
$lng->{errNoAccess}  = "Zugriff verweigert.";
$lng->{errBannedT}   = "Benutzerkonto ist gesperrt. Grund:";
$lng->{errBannedT2}  = "Dauer: ";
$lng->{errBannedT3}  = "Tage.";
$lng->{errBlockEmlT} = "Ihre Email-Domain ist auf der schwarzen Liste des Forums.";
$lng->{errBlockIp}   = "Ihre IP-Adresse ist auf der schwarzen Liste des Forums.";
$lng->{errSubLen}    = "Maximale Betrefflänge überschritten.";
$lng->{errBdyLen}    = "Maximale Nachrichtenlänge überschritten.";
$lng->{errOptLen}    = "Maximale Optionslänge überschritten.";
$lng->{errTpcLocked} = "Thema ist gesperrt.";
$lng->{errPstLocked} = "Nachricht ist gesperrt.";
$lng->{errSubNoText} = "Betreff enthält keinen echten Text.";
$lng->{errNamGone}   = "Name ist schon vergeben.";
$lng->{errNamResrvd} = "Name enthält reservierten Text.";
$lng->{errEmlGone}   = "Emailadresse ist schon registriert. Es ist nur ein Konto pro Adresse erlaubt.";
$lng->{errPwdDiffer} = "Passwörter sind nicht identisch.";
$lng->{errEmlDiffer} = "Emailadressen sind nicht identisch.";
$lng->{errDupe}      = "Nachricht ist schon eingetragen.";
$lng->{errAttName}   = "Keine Datei oder kein Dateiname angegeben.";
$lng->{errAttSize}   = "Upload fehlt, wurde abgeschnitten oder übertrifft maximale Größe.";
$lng->{errPromoTpc}  = "Diese Nachricht ist die Basisnachricht des ganzen Themas.";
$lng->{errPstEdtTme} = "Nachrichten können nur einen begrenzte Zeitraum nach dem Abschicken editiert werden. Dieser Zeitraum ist bereits abgelaufen.";
$lng->{errDontEmail} = "Das Senden von Emails für Ihr Konto wurde deaktiviert. Typische Gründe dafür sind ungültige Emailadressen, überfüllte Postfächer oder aktivierte Autoresponder.";
$lng->{errEditAppr}  = "Das Editieren von Nachrichten in moderierten Brettern ist nicht mehr erlaubt, sobald sie von einem Administrator oder Moderator bestätigt wurden.";
$lng->{errRepDupe}   = "Es gibt bereits eine Meldung dieser Nachricht.";
$lng->{errRepReason} = "Begründung ist leer.";
$lng->{errSrcAuth}   = "Zugriffsquellen-Authentifizierung ist fehlgeschlagen. Entweder hat jemand versucht, Ihnen eine Aktion unterzuschieben (speziell falls Sie gerade von einer fremden Seite gekommen sind), oder Sie haben eine Forumsseite zu lange offen gelassen.";
$lng->{errPolExist}  = "Thema hat bereits eine Umfrage.";
$lng->{errPolOptNum} = "Umfrage hat zuwenig oder zuviele Optionen.";
$lng->{errPolNoDel}  = "Nur Umfragen ohne abgegebene Stimmen können gelöscht werden.";
$lng->{errPolNoOpt}  = "Keine Option ausgewählt.";
$lng->{errPolNotFnd} = "Umfrage existiert nicht.";
$lng->{errPolLocked} = "Umfrage ist beendet.";
$lng->{errPolOpNFnd} = "Umfrageoption existiert nicht.";
$lng->{errPolVotedP} = "Sie können nur einmal für diese Umfrage abstimmen.";
$lng->{errAvaSizeEx} = "Maximale Dateigröße überschritten.";
$lng->{errAvaDimens} = "Bild muss angegebene Breite und Höhe haben.";
$lng->{errAvaFmtUns} = "Dateiformat ungültig oder nicht unterstützt.";
$lng->{errAvaNoAnim} = "Animierte Bilder sind nicht erlaubt.";
$lng->{errRepostTim} = "Spamschutz aktiviert. Bitte warten Sie [[seconds]] Sekunden, bis Sie wieder eine Nachricht abschicken können.";
$lng->{errCrnEmuBsy} = "Das Forum ist zurzeit mit Wartungsarbeiten beschäftigt. Bitte kommen Sie später wieder.";
$lng->{errForumLock} = "Das Forum ist zurzeit geschlossen. Bitte kommen Sie später wieder.";
$lng->{errMinRegTim} = "Sie müssen für mindestens [[hours]] Stunde(n) registriert sein, um diese Funktion benutzen zu können.";
$lng->{errDbHidden}  = "Ein Datenbankfehler ist aufgetreten und wurde geloggt.";
$lng->{errCptTmeOut} = "Anti-Spam-Bild ist abgelaufen. Sie haben [[seconds]] Sekunden Zeit, um das Formular abzuschicken.";
$lng->{errCptWrong}  = "Buchstaben vom Anti-Spam-Bild sind nicht korrekt. Bitte versuchen Sie es nochmal.";
$lng->{errCptFail}   = "Sie haben den Anti-Spam-Test nicht bestanden.";
$lng->{errOidEmpty}  = "OpenID-URL ist leer";
$lng->{errOidLen}    = "OpenID-URL ist zu lang.";
$lng->{errOidPrNtAc} = "OpenID-Provider ist nicht auf der Liste der akzeptierten Provider.";
$lng->{errOidNotFnd} = "OpenID-URL oder Provider nicht gefunden.";
$lng->{errOidCancel} = "OpenID-Überprüfung wurde vom Benutzer abgebrochen.";
$lng->{errOidReplay} = "OpenID-Wiederholungsangriff festgestellt.";
$lng->{errOidFail}   = "OpenID-Überprüfung ist fehlgeschlagen.";
$lng->{errWordSize}  = "Wort ist zu kurz oder zu lang.";
$lng->{errWordChar}  = "Wort enthält ungültige Zeichen.";
$lng->{errWatchNum}  = "Maximale Anzahl an Überwachungseinträgen verwendet.";
$lng->{errFgtPwdDuh} = "Sie haben diese Funktion vor kurzem schon benutzt oder sich gerade erst registriert. Bitte warten Sie auf die Email, und überprüfen Sie auch Ihren Spam-Ordner.";
$lng->{errRecvNum}   = "Zu viele Empfänger.";
$lng->{errOldAgent}  = "Ihr Webbrowser ist hoffnungslos veraltet und wird von diesem Forum nicht mehr unterstützt. Bitte installieren Sie einen <a href='http://www.mozilla.org/firefox'>besseren Browser</a>.";
$lng->{errUAFeatSup} = "Ihr Webbrowser unterstützt diese Funktion nicht.";
$lng->{errNoCookies} = "Anmelden wird nicht funktionieren, da Browser-Cookies deaktiviert sind.";
$lng->{errSearchLnk} = "Verlinkte Suchergebnisse sind deaktiviert.";


#------------------------------------------------------------------------------
# Help

$lng->{help} = "

<p>Hinweis: da mwForum sehr konfigurabel ist, sind nicht alle unten genannten 
Funktionen zwangsweise in jeder Installation verfügbar.</p>

<h3>Forum</h3>

<p>Als Forum wird die komplette Installation bezeichnet, die gewöhnlich mehrere 
Bretter enthält. Man sollte das Forum immer durch den Link betreten, der auf 
\"forum.pl\" (nicht \"forum_show.pl\") endet, damit das Forum weiß, wann man eine 
Session beginnt, und berechnen kann, welche Nachrichten alt und welche neu 
sind.</p>

<h3>Benutzer</h3>

<p>Ein Benutzer ist jemand, der im Forum ein Konto registriert hat. Zum Lesen 
ist zwar im allgemeinen kein Konto notwendig, allerdings haben unregistrierte 
Gäste je nach Konfiguration keinen Zugriff auf bestimmte Bretter oder 
Funktionen.</p>

<h3>Gruppe</h3>

<p>Benutzer können Mitglieds-Status in Gruppen bekommen, bzw. sich selbst 
offenen Gruppen anschließen. Die Gruppen wiederum können Mitglieds- oder 
Moderator-Status in ausgewählten Brettern bekommen, und dadurch ihren 
Mitgliedern die entsprechenden Lese/Schreib- oder Moderatoren-Rechte in den 
betroffenen Brettern verleihen.</p>

<h3>Brett</h3>

<p>Ein Brett enthält Themen zu einem dem Brettnamen entsprechenden 
Themenbereich. Bretter können so eingestellt werden, so dass sie nur für 
registrierte Benutzer oder nur für Moderatoren und Brettmitglieder sichtbar 
sind. Bretter können optional das Schreiben von Nachrichten durch unregistrierte 
Besucher erlauben. Bretter können schreibgeschützt sein, so dass nur Moderatoren 
und Mitglieder in ihnen schreiben können, sowie so eingestellt werden, dass nur 
Moderatoren und Mitglieder neue Themen starten können, auf die dann aber jeder 
Benutzer antworten kann. Eine weitere Option für Bretter nennt sich 
Bestätigungsmoderation, bei deren Aktivierung neue Nachrichten von Moderatoren 
bestätigt werden müssen, um für normale Benutzer sichtbar zu sein.</p>

<h3>Thema</h3>

<p>Ein Thema enthält alle Nachrichten zu einer bestimmten Angelegenheit, die im 
Betreff angegeben sein sollte. Die Nachrichten können entweder in einer 
Baumstruktur angeordnet sein, der man entnehmen kann, welche Nachricht sich auf 
welchen Vorgänger bezieht, oder sie können alle sequentiell hintereinander 
stehen. Bretter haben Zeiten, die angeben, wie lange es dauert, bevor ihre 
Themen gelöscht und/oder gesperrt werden. Themen können von Moderatoren auch 
manuell gesperrt werden, so dass man keine Nachrichten schreiben oder editieren 
kann.</p>

<h3>Öffentliche Nachricht</h3>

<p>Eine Nachricht ist ein öffentlicher Kommentar eines Benutzers zu einem Thema. 
Es kann entweder eine Nachricht mit Betreff sein, die ein neues Thema beginnt, 
oder eine Antwort zu einem existierenden Thema. Nachrichten können nachträglich 
editiert und gelöscht werden, was allerdings zeitlich begrenzt sein kann. 
Moderatoren können Nachrichten sperren, so dass keine Antworten oder 
Veränderungen mehr möglich sind. Nachrichten können im Falle von Regelverstößen 
den Moderatoren gemeldet werden.</p>

<h3>Private Nachricht</h3>

<p>Zusätzlich zu den mehr oder weniger öffentlichen Nachrichten können in einem 
Forum auch die privaten Nachrichten aktiviert sein, die sich registrierte 
Benutzer gegenseitig zuschicken können, ohne die Emailadresse der anderen zu 
kennen.</p>

<h3>Administrator</h3>

<p>Administratoren können alles im Forum kontrollieren und editieren, und damit 
auch global als Moderatoren fungieren. Die Administratoren sind auf der 
Infoseite des Forums aufgelistet.</p>

<h3>Moderator</h3>

<p>Die Macht von Moderatoren ist auf bestimmte Bretter beschränkt, in denen sie 
Nachrichten editieren, sperren, löschen und bestätigen, Themen sperren und 
löschen, sowie Meldungen einsehen können. Die Benutzergruppen, deren 
Mitglieder in einem Brett Moderator-Rechte haben, sind auf der Infoseite des 
Brettes aufgelistet.</p>

<h3>Umfragen</h3>

<p>Der Besitzer eines Themas kann diesem eine Umfrage hinzufügen. Jede Umfrage 
kann bis zu 20 Optionen enthalten. Umfragen können entweder eine Stimme für eine 
einzige Option erlauben, oder alternativ mehrere Stimmen für verschiedene 
Optionen zu verschiedenen Zeitpunkten. Umfragen können nicht editiert werden, 
und können nur so lange wieder gelöscht werden, wie noch keine Stimme abgegeben 
wurde.</p>

<h3>Icons</h3>

<table>
<tr><td>
<img class='sic sic_post_nu' src='[[dataPath]]/epx.png' alt='N/U'>
<img class='sic sic_topic_nu' src='[[dataPath]]/epx.png' alt='N/U'>
<img class='sic sic_board_nu' src='[[dataPath]]/epx.png' alt='N/U'>
</td><td>
Gelbe Icons zeigen neue Nachrichten, Themen oder Bretter mit neuen Nachrichten 
an. In diesem Forum bedeutet neu, dass eine Nachricht seit dem letzten Besuch 
hinzugekommen ist. Auch wenn eine Nachricht gerade gelesen wurde, gilt sie immer 
noch als neu, und wird erst beim nächsten Forumsbesuch als alt gewertet.
</td></tr>
<tr><td>
<img class='sic sic_post_or' src='[[dataPath]]/epx.png' alt='O/R'>
<img class='sic sic_topic_or' src='[[dataPath]]/epx.png' alt='O/R'>
<img class='sic sic_board_or' src='[[dataPath]]/epx.png' alt='O/R'>
</td><td>
Abgehakte Icons bedeuten, dass eine Nachricht oder alle Nachrichten in einem
Thema oder Brett gelesen wurden. Als gelesen werden alle Nachrichten gewertet,
die einmal anzeigt wurden oder älter als eine bestimmte Anzahl von Tagen
sind. Da neu/alt und ungelesen/gelesen in diesem Forum unabhängige Konzepte
sind, können Nachrichten auch gleichzeitig neu und gelesen sowie alt und
ungelesen sein.
</td></tr>
<tr><td>
<img class='sic sic_post_i' src='[[dataPath]]/epx.png' alt='I'>
</td><td>
Die Nachricht oder das Thema sind für andere Benutzer unsichtbar, da sie noch 
auf Bestätigung durch einen Moderator warten.
</td></tr>
<tr><td>
<img class='sic sic_topic_l' src='[[dataPath]]/epx.png' alt='L'>
</td><td>
Die Nachricht oder das Thema sind gesperrt. Es kann weder geantwortet 
noch editiert werden.
</td></tr>
</table>

<h3>Formatierungs-Tags</h3>

<p>Aus Sicherheitsgründen unterstützt mwForum nur seine eigenen 
Formatierungs-Tags, kein HTML. Verfügbare Tags:</p>

<table>
<tr><td>[b]Text[/b]</td>
<td>zeigt Text <b>fett</b> an</td></tr>
<tr><td>[i]Text[/i]</td>
<td>zeigt Text <i>kursiv</i> an</td></tr>
<tr><td>[tt]Text[/tt]</td>
<td>zeigt Text <code>nichtproportional</code> an</td></tr>
<tr><td>[url]Adresse[/url]</td>
<td>macht die Adresse zu einem Link</td></tr>
<tr><td>[url=Adresse]Text[/url]</td>
<td>macht Text zu einem Link für die Adresse</td></tr>
<tr><td>[img]Adresse[/img]</td>
<td>bettet ein externes Bild ein (wenn erlaubt)</td></tr>
<tr><td>[img]Dateiname[/img]</td>
<td>bettet ein angehängtes Bild ein</td></tr>
<tr><td>[img thb]Dateiname[/img]</td>
<td>bettet die Vorschau eines angehängten Bildes ein (wenn verfügbar)</td></tr>
</table>

<h3>Zitate</h3>

<p>mwForum benutzt ein Zitatformat wie bei Email. Um jemanden zu zitieren, 
kopieren Sie einfach eine Zeile aus dem Text der Ursprungsnachricht, und stellen 
Sie ihr ein &gt;-Zeichen voran. Das Zitat wird dann später in einer anderen 
Farbe hervorgehoben. Bitte zitieren Sie nicht mehr Text als nötig, um den 
Kontext herzustellen. Einige Foren können auch automatisches Zitieren aktiviert 
haben. In dem Fall reduzieren Sie bitte auch den Zitattext auf das nötige.</p>

<h3>Tastaturnavigation</h3>

<p>Nachrichten auf Themenseiten in Brettern mit Baumstruktur können mit den 
WASD-Tasten auf die gleiche Weise navigiert werden, wie dies bei einem typischen 
Baumansichts-Kontrollelement mit den Pfeiltasten der Fall ist. Zusätzlich kann 
man mit der Taste E zur nächsten neuen oder ungelesenen Nachricht springen.</p>

";

#------------------------------------------------------------------------------
# FAQ

$lng->{faq} = "

<h3>Warum werden alte Nachrichten nicht als alt angezeigt?</h3>

<p>Sie müssen das Forum durch einen Link betreten, der in \"forum.pl\" endet 
(nicht \"forum_show.pl\"), um das Forum wissen zu lassen, dass Sie eine neue 
Session starten wollen. Sollten Sie aus welchem Grund auch immer eine alte 
Session fortsetzen wollen, können Sie das Forum auch direkt durch 
\"forum_show.pl\" betreten, ohne dass Nachrichten als alt markiert werden.</p>

<h3>Ich habe mein Passwort verloren, können Sie mir das zuschicken?</h3>

<p>Das originale Passwort wird aus Sicherheitsgründen nirgendwo gespeichert. Auf 
der Anmeldeseite können Sie jedoch eine Email mit einer speziellen Ticket-URL 
anfordern, die eine begrenzte Zeit gültig ist, und mit der Sie wieder einloggen 
können. Danach können Sie dann ein neues Passwort setzen.</p>

<h3>Wann muss man sich abmelden?</h3>

<p>Man braucht sich nur abzumelden, wenn der benutzte Computer auch von nicht
vertrauenswürdigen Personen benutzt wird. Wie oben geschrieben werden
Benutzer-ID und Passwort per Cookie auf dem Computer gespeichert. Diese werden
beim Abmelden entfernt, so dass sie nicht von einer anderen Person missbraucht
werden können.</p>

<h3>Wie kann man Bilder und andere Dateien an Nachrichten anhängen?</h3>

<p>Wenn Dateianhänge in diesem Forum aktiviert sind, muss man zuerst 
ganz normal eine öffentliche Nachricht abschicken. Danach kann man den 
\"Anhängen\"-Knopf der Nachricht benutzen und so zur Dateianhangs-Seite 
gelangen. Das Schreiben einer Nachricht und das Hochladen sind auf 
diese Weise getrennt, da das Hochladen aus verschiedenen Gründen 
fehlschlagen kann, und es nicht gut wäre, wenn dabei der normale 
Nachrichtentext verlorenginge.</p>

";

#------------------------------------------------------------------------------

# Load local string overrides
do 'MwfGermanLocal.pm';

#------------------------------------------------------------------------------
# Return OK
1;
