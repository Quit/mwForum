#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright © 1999-2012 Markus Wichitill
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

package MwfEnglish;
use utf8;
use strict;
our $VERSION = "2.27.3";
our $lng = {};

#------------------------------------------------------------------------------

# Language module meta information
$lng->{author}       = "Markus Wichitill";

#------------------------------------------------------------------------------

# Common strings
$lng->{comUp}        = "Up";
$lng->{comUpTT}      = "Go up a level";
$lng->{comPgPrev}    = "Previous";
$lng->{comPgPrevTT}  = "Go to previous page";
$lng->{comPgNext}    = "Next";
$lng->{comPgNextTT}  = "Go to next page";
$lng->{comBoardList} = "Forum";
$lng->{comNew}       = "N";
$lng->{comNewTT}     = "New";
$lng->{comOld}       = "-";
$lng->{comOldTT}     = "Old";
$lng->{comNewUnrd}   = "N/U";
$lng->{comNewUnrdTT} = "New/Unread";
$lng->{comNewRead}   = "N/-";
$lng->{comNewReadTT} = "New/Read";
$lng->{comOldUnrd}   = "-/U";
$lng->{comOldUnrdTT} = "Old/Unread";
$lng->{comOldRead}   = "-/-";
$lng->{comOldReadTT} = "Old/Read";
$lng->{comAnswer}    = "A";
$lng->{comAnswerTT}  = "Answered";
$lng->{comShowNew}   = "New Posts";
$lng->{comShowNewTT} = "Show new posts";
$lng->{comShowUnr}   = "Unread Posts";
$lng->{comShowUnrTT} = "Show unread posts";
$lng->{comFeeds}     = "Feeds";
$lng->{comFeedsTT}   = "Show Atom/RSS feeds";
$lng->{comCaptcha}   = "Please type the six characters from the anti-spam image";

# Header
$lng->{hdrForum}     = "Forum";
$lng->{hdrForumTT}   = "Forum start page";
$lng->{hdrHomeTT}    = "Associated homepage";
$lng->{hdrProfile}   = "Profile";
$lng->{hdrProfileTT} = "Edit user profile";
$lng->{hdrOptions}   = "Options";
$lng->{hdrOptionsTT} = "Edit user options";
$lng->{hdrHelp}      = "Help";
$lng->{hdrHelpTT}    = "Help and FAQ";
$lng->{hdrSearch}    = "Search";
$lng->{hdrSearchTT}  = "Search posts for keywords";
$lng->{hdrChat}      = "Chat";
$lng->{hdrChatTT}    = "Read and write chat messages";
$lng->{hdrMsgs}      = "Messages";
$lng->{hdrMsgsTT}    = "Read and write private messages";
$lng->{hdrLogin}     = "Login";
$lng->{hdrLoginTT}   = "Login with username and password";
$lng->{hdrLogout}    = "Logout";
$lng->{hdrLogoutTT}  = "Logout";
$lng->{hdrReg}       = "Register";
$lng->{hdrRegTT}     = "Register user account";
$lng->{hdrOpenId}    = "OpenID";
$lng->{hdrOpenIdTT}  = "Login with OpenID";
$lng->{hdrNoLogin}   = "Not logged in";
$lng->{hdrWelcome}   = "Logged in as";
$lng->{hdrArchive}   = "Archive";

# Forum page
$lng->{frmTitle}     = "Forum";
$lng->{frmMarkOld}   = "Mark Old";
$lng->{frmMarkOldTT} = "Mark all posts as old";
$lng->{frmMarkRd}    = "Mark Read";
$lng->{frmMarkRdTT}  = "Mark all posts as read";
$lng->{frmUsers}     = "Users";
$lng->{frmUsersTT}   = "Show user list";
$lng->{frmAttach}    = "Attachments";
$lng->{frmAttachTT}  = "Show attachment list";
$lng->{frmInfo}      = "Info";
$lng->{frmInfoTT}    = "Show forum info";
$lng->{frmNotTtl}    = "Notifications";
$lng->{frmNotDelB}   = "Remove notifications";
$lng->{frmCtgCollap} = "Collapse category";
$lng->{frmCtgExpand} = "Expand category";
$lng->{frmPosts}     = "Posts";
$lng->{frmLastPost}  = "Last Post";
$lng->{frmRegOnly}   = "Registered users only";
$lng->{frmMbrOnly}   = "Board members only";
$lng->{frmNew}       = "new";
$lng->{frmNoBoards}  = "No visible boards.";
$lng->{frmStats}     = "Statistics";
$lng->{frmOnlUsr}    = "Online";
$lng->{frmOnlUsrTT}  = "Users online in the past 5 minutes";
$lng->{frmNewUsr}    = "New";
$lng->{frmNewUsrTT}  = "Users registered in the past 5 days";
$lng->{frmBdayUsr}   = "Birthday";
$lng->{frmBdayUsrTT} = "Users that have their birthday today";

# Forum info page
$lng->{fifTitle}     = "Forum";
$lng->{fifBrowsers}  = "Browsers";
$lng->{fifCountries} = "Countries";
$lng->{fifActivity}  = "Activity";
$lng->{fifGenTtl}    = "General Info";
$lng->{fifGenAdmEml} = "Email Address";
$lng->{fifGenAdmins} = "Administrators";
$lng->{fifGenTZone}  = "Timezone";
$lng->{fifGenVer}    = "Forum Version";
$lng->{fifGenLang}   = "Languages";
$lng->{fifStsTtl}    = "Statistics";
$lng->{fifStsUsrNum} = "Users";
$lng->{fifStsTpcNum} = "Topics";
$lng->{fifStsPstNum} = "Posts";

# User agents page
$lng->{uasTitle}     = "User Agents";
$lng->{uasUsersT}    = "Counting [[users]] users logged in during the last [[days]] days.";
$lng->{uasChartTtl}  = "Charts";
$lng->{uasUaTtl}     = "Browsers";
$lng->{uasOsTtl}     = "Operating Systems";

# User countries page
$lng->{ucoTitle}     = "User Countries";
$lng->{ucoMapTtl}    = "Map";
$lng->{ucoCntryTtl}  = "Countries";

# Forum activity page
$lng->{actTitle}     = "Forum Activity";
$lng->{actPstDayT}   = "Horizontal axis: one pixel per day, vertical axis: one pixel per post. Only existing posts are counted.";
$lng->{actPstDayTtl} = "Posts Per Day";
$lng->{actPstYrTtl}  = "Posts Per Year";

# New/unread overview page
$lng->{ovwTitleNew}  = "New Posts";
$lng->{ovwTitleUnr}  = "Unread Posts";
$lng->{ovwMore}      = "More";
$lng->{ovwMoreTT}    = "Show more posts on the next page";
$lng->{ovwRefresh}   = "Refresh";
$lng->{ovwRefreshTT} = "Refresh page";
$lng->{ovwMarkOld}   = "Mark Old";
$lng->{ovwMarkOldTT} = "Mark all posts as old";
$lng->{ovwMarkRd}    = "Mark Read";
$lng->{ovwMarkRdTT}  = "Mark all posts as read";
$lng->{ovwFltTpc}    = "Filter";
$lng->{ovwFltTpcTT}  = "Only show this topic";
$lng->{ovwEmpty}     = "No visible posts found.";
$lng->{ovwMaxCutoff} = "Topic has too many posts, skipping rest.";

# Board page
$lng->{brdTitle}     = "Board";
$lng->{brdNewTpc}    = "Post";
$lng->{brdNewTpcTT}  = "Post new topic";
$lng->{brdInfo}      = "Info";
$lng->{brdInfoTT}    = "Show board info";
$lng->{brdMarkRd}    = "Mark Read";
$lng->{brdMarkRdTT}  = "Mark all posts in board as read";
$lng->{brdTopic}     = "Topic";
$lng->{brdPoster}    = "User";
$lng->{brdPosts}     = "Posts";
$lng->{brdLastPost}  = "Last Post";
$lng->{brdLocked}    = "L";
$lng->{brdLockedTT}  = "Locked";
$lng->{brdInvis}     = "I";
$lng->{brdInvisTT}   = "Invisible";
$lng->{brdPoll}      = "P";
$lng->{brdPollTT}    = "Poll";
$lng->{brdNew}       = "new";
$lng->{brdAdmin}     = "Administration";
$lng->{brdAdmRep}    = "Reports";
$lng->{brdAdmRepTT}  = "Show reported posts";
$lng->{brdAdmGrp}    = "Groups";
$lng->{brdAdmGrpTT}  = "Edit group permissions";
$lng->{brdAdmSpl}    = "Split";
$lng->{brdAdmSplTT}  = "Mass-move topics to other boards";
$lng->{brdBoardFeed} = "Board Feed";

# Board info page
$lng->{bifTitle}     = "Board";
$lng->{bifOptTtl}    = "Options";
$lng->{bifOptDesc}   = "Description";
$lng->{bifOptLock}   = "Locking";
$lng->{bifOptLockT}  = "days after last post, topics will be locked";
$lng->{bifOptExp}    = "Expiration";
$lng->{bifOptExpT}   = "days after last post, topics will be deleted";
$lng->{bifOptAttc}   = "Attachments";
$lng->{bifOptAttcY}  = "File attachments are enabled";
$lng->{bifOptAttcN}  = "File attachments are disabled";
$lng->{bifOptAprv}   = "Moderation";
$lng->{bifOptAprvY}  = "Posts have to be approved to be visible";
$lng->{bifOptAprvN}  = "Posts don't have to be approved to be visible";
$lng->{bifOptPriv}   = "Read Access";
$lng->{bifOptPriv0}  = "All users can see board";
$lng->{bifOptPriv1}  = "Only admins/moderators/members can see board";
$lng->{bifOptPriv2}  = "Only registered users can see board";
$lng->{bifOptAnnc}   = "Write Access";
$lng->{bifOptAnnc0}  = "All users can post";
$lng->{bifOptAnnc1}  = "Only admins/moderators/members can post";
$lng->{bifOptAnnc2}  = "Only admins/moderators/members can start topics, all users can reply";
$lng->{bifOptUnrg}   = "Registration";
$lng->{bifOptUnrgY}  = "Posting doesn't require registration";
$lng->{bifOptUnrgN}  = "Posting requires registration";
$lng->{bifOptFlat}   = "Threading";
$lng->{bifOptFlatY}  = "Topics are non-threaded";
$lng->{bifOptFlatN}  = "Topics are threaded";
$lng->{bifAdmsTtl}   = "Moderator Groups";
$lng->{bifMbrsTtl}   = "Member Groups";
$lng->{bifStatTtl}   = "Statistics";
$lng->{bifStatTPst}  = "Posts";
$lng->{bifStatLPst}  = "Last Post";

# Topic page
$lng->{tpcTitle}     = "Topic";
$lng->{tpcTpcRepl}   = "Post";
$lng->{tpcTpcReplTT} = "Post concerning the topic in general";
$lng->{tpcTag}       = "Tag";
$lng->{tpcTagTT}     = "Set topic tag";
$lng->{tpcSubs}      = "Subscribe";
$lng->{tpcSubsTT}    = "Enable email subscription of topic";
$lng->{tpcPolAdd}    = "Poll";
$lng->{tpcPolAddTT}  = "Add poll";
$lng->{tpcPolDel}    = "Delete";
$lng->{tpcPolDelTT}  = "Delete poll";
$lng->{tpcPolLock}   = "Close";
$lng->{tpcPolLockTT} = "Close poll (irreversible)";
$lng->{tpcPolTtl}    = "Poll";
$lng->{tpcPolLocked} = "(Closed)";
$lng->{tpcPolVote}   = "Vote";
$lng->{tpcPolShwRes} = "Show results";
$lng->{tpcHidTtl}    = "Hidden post";
$lng->{tpcHidIgnore} = "(ignored) ";
$lng->{tpcHidUnappr} = "(unapproved) ";
$lng->{tpcApprv}     = "Approve";
$lng->{tpcApprvTT}   = "Make post visible to users";
$lng->{tpcLock}      = "Lock";
$lng->{tpcLockTT}    = "Lock post to disable editing and replying";
$lng->{tpcUnlock}    = "Unlock";
$lng->{tpcUnlockTT}  = "Unlock post to enable editing and replying";
$lng->{tpcReport}    = "Notify";
$lng->{tpcReportTT}  = "Notify users or moderators about this post";
$lng->{tpcBranch}    = "Branch";
$lng->{tpcBranchTT}  = "Promote/move/lock/delete branch";
$lng->{tpcEdit}      = "Edit";
$lng->{tpcEditTT}    = "Edit post";
$lng->{tpcDelete}    = "Delete";
$lng->{tpcDeleteTT}  = "Delete post";
$lng->{tpcAttach}    = "Attach";
$lng->{tpcAttachTT}  = "Upload and delete attachments";
$lng->{tpcReply}     = "Reply";
$lng->{tpcReplyTT}   = "Reply to post";
$lng->{tpcQuote}     = "Quote";
$lng->{tpcQuoteTT}   = "Reply to post with quote";
$lng->{tpcBrnCollap} = "Collapse branch";
$lng->{tpcBrnExpand} = "Expand branch";
$lng->{tpcNxtPst}    = "Next";
$lng->{tpcNxtPstTT}  = "Go to next new or unread post";
$lng->{tpcParent}    = "Parent";
$lng->{tpcParentTT}  = "Go to parent post";
$lng->{tpcInvis}     = "I";
$lng->{tpcInvisTT}   = "Invisible";
$lng->{tpcAttText}   = "Attachment:";
$lng->{tpcAdmStik}   = "Stick";
$lng->{tpcAdmUnstik} = "Unstick";
$lng->{tpcAdmLock}   = "Lock";
$lng->{tpcAdmUnlock} = "Unlock";
$lng->{tpcAdmMove}   = "Move";
$lng->{tpcAdmMerge}  = "Merge";
$lng->{tpcAdmDelete} = "Delete";
$lng->{tpcBy}        = "By";
$lng->{tpcOn}        = "Date";
$lng->{tpcEdited}    = "Edited";
$lng->{tpcLocked}    = "(locked)";

# Topic subscription page
$lng->{tsbTitle}     = "Topic";
$lng->{tsbSubTtl}    = "Subscribe to Topic";
$lng->{tsbSubT2}     = "Instant subscriptions send out new posts in the selected topic to you by email instantly. Digest subscriptions send out collected posts regularly (usually daily).";
$lng->{tsbInstant}   = "Instant subscription";
$lng->{tsbDigest}    = "Digest subscription";
$lng->{tsbSubB}      = "Subscribe";
$lng->{tsbUnsubTtl}  = "Unsubscribe Topic";
$lng->{tsbUnsubB}    = "Unsubscribe";

# Add poll page
$lng->{aplTitle}     = "Add Poll";
$lng->{aplPollTitle} = "Poll title or question";
$lng->{aplPollOpts}  = "Options (one option per line, max. 20 options, max. 60 characters per option, no markup)";
$lng->{aplPollMulti} = "Allow multiple votes for different options";
$lng->{aplPollNote}  = "You can't edit polls, and you can't delete them once someone has voted, so please check your poll title and options before adding the poll.";
$lng->{aplPollAddB}  = "Add";

# Add report page
$lng->{arpTitle}     = "Post";
$lng->{arpPngTtl}    = "Notify User";
$lng->{arpPngT}      = "Sends a notification about this post to someone's notification list and optionally by email.";
$lng->{arpPngUser}   = "Recipient";
$lng->{arpPngEmail}  = "Send by email, too";
$lng->{arpPngB}      = "Notify";
$lng->{arpPngMlSbPf} = "Notification from";
$lng->{arpPngMlT}    = "This is a post notification from the forum software.\nPlease don't reply to this email.";
$lng->{arpRepTtl}    = "Report to Moderators";
$lng->{arpRepT}      = "If you think that a post violates the law or the rules of this forum, you can report it to moderators and administrators.";
$lng->{arpRepYarly}  = "I want to report the post, not reply to it";
$lng->{arpRepReason} = "Reason";
$lng->{arpRepB}      = "Report";
$lng->{arpThrTtl}    = "Advise about Threaded Structure";
$lng->{arpThrT}      = "If a user has posted a reply to the wrong post, you can send them a notification that asks them to reply to the correct posts to preserve the threaded structure of topics. This is generally preferable to public posts doing the same. Can only be used by admins/mods, within 24 hours and once per recipient to avoid flooding.";
$lng->{arpThrB}      = "Advise";

# Report list page
$lng->{repTitle}     = "Reported Posts";
$lng->{repBy}        = "Report By";
$lng->{repTopic}     = "Topic";
$lng->{repPoster}    = "User";
$lng->{repPosted}    = "Posted";
$lng->{repDeleteB}   = "Remove report";
$lng->{repEmpty}     = "No reported posts.";

# Tag button bar
$lng->{tbbMod}       = "Mod";
$lng->{tbbBold}      = "Bold";
$lng->{tbbItalic}    = "Italic";
$lng->{tbbTeletype}  = "Teletype";
$lng->{tbbImage}     = "Image";
$lng->{tbbVideo}     = "Video";
$lng->{tbbCustom}    = "Custom";
$lng->{tbbInsSnip}   = "Insert text";

# Reply page
$lng->{rplTitle}     = "Topic";
$lng->{rplTopicTtl}  = "Post Concerning the Topic in General";
$lng->{rplReplyTtl}  = "Post Reply";
$lng->{rplReplyT}    = "This board is threaded (i.e. has a tree structure). Please use the Reply button of the specific post you are referring to, not just any random button. If you want to reply to the topic in general, use the Post button near the top and bottom of the page.";
$lng->{rplReplyName} = "Name";
$lng->{rplReplyIRaw} = "Insert raw text";
$lng->{rplReplyRaw}  = "Raw text (e.g. source code)";
$lng->{rplReplyResp} = "In Response to";
$lng->{rplReplyB}    = "Post";
$lng->{rplReplyPrvB} = "Preview";
$lng->{rplPrvTtl}    = "Preview";
$lng->{rplEmailSbPf} = "Reply from";
$lng->{rplEmailT2}   = "This is a reply notification from the forum software.\nPlease don't reply to this email.";
$lng->{rplAgeOrly}   = "The post you are replying to is already [[age]] days old. Are you sure that you want to reply to a post that old?";
$lng->{rplAgeYarly}  = "Yes, I have a good reason for doing so";

# New topic page
$lng->{ntpTitle}     = "Board";
$lng->{ntpTpcTtl}    = "Post New Topic";
$lng->{ntpTpcName}   = "Name";
$lng->{ntpTpcSbj}    = "Subject";
$lng->{ntpTpcIRaw}   = "Insert raw text";
$lng->{ntpTpcRaw}    = "Raw text (e.g. source code)";
$lng->{ntpTpcNtfy}   = "Receive reply notifications";
$lng->{ntpTpcB}      = "Post";
$lng->{ntpTpcPrvB}   = "Preview";
$lng->{ntpPrvTtl}    = "Preview";

# Post edit page
$lng->{eptTitle}     = "Post";
$lng->{eptEditTtl}   = "Edit Post";
$lng->{eptEditSbj}   = "Subject";
$lng->{eptEditIRaw}  = "Insert raw text";
$lng->{eptEditRaw}   = "Raw text (e.g. source code)";
$lng->{eptEditB}     = "Change";
$lng->{eptEditPrvB}  = "Preview";
$lng->{eptPrvTtl}    = "Preview";
$lng->{eptDeleted}   = "[deleted]";

# Post attachments page
$lng->{attTitle}     = "Post Attachments";
$lng->{attDelAll}    = "Delete All";
$lng->{attDelAllTT}  = "Delete all attachments";
$lng->{attDropNote}  = "You can also upload files by dropping them onto the form.";
$lng->{attGoPostT}   = "The up-arrow icon leads back to the post.";
$lng->{attUplTtl}    = "Upload";
$lng->{attUplFiles}  = "File(s) (max. file size [[size]])";
$lng->{attUplCapt}   = "Caption";
$lng->{attUplEmbed}  = "Embed (only JPG, PNG and GIF images)";
$lng->{attUplB}      = "Upload";
$lng->{attAttTtl}    = "Attachment";
$lng->{attAttDelB}   = "Delete";
$lng->{attAttChgB}   = "Change";

# Attachment page
$lng->{atsTitle}     = "Attachment";
$lng->{atsPrev}      = "Previous";
$lng->{atsPrevTT}    = "Go to previous attachment";
$lng->{atsNext}      = "Next";
$lng->{atsNextTT}    = "Go to next attachment";

# User info page
$lng->{uifTitle}     = "User";
$lng->{uifListPst}   = "Posts";
$lng->{uifListPstTT} = "Show posts by this user";
$lng->{uifMessage}   = "Send Message";
$lng->{uifMessageTT} = "Send private message to this user";
$lng->{uifIgnore}    = "Ignore";
$lng->{uifIgnoreTT}  = "Ignore this user";
$lng->{uifWatch}     = "Watch";
$lng->{uifWatchTT}   = "Put user on watch list";
$lng->{uifProfTtl}   = "Profile";
$lng->{uifProfUName} = "Username";
$lng->{uifProfOName} = "Old Names";
$lng->{uifProfRName} = "Real Name";
$lng->{uifProfBdate} = "Birthday";
$lng->{uifProfPage}  = "Website";
$lng->{uifProfOccup} = "Occupation";
$lng->{uifProfHobby} = "Hobbies";
$lng->{uifProfLocat} = "Location";
$lng->{uifProfGeoIp} = "Location (IP-based)";
$lng->{uifProfIcq}   = "Email/Messengers";
$lng->{uifProfSig}   = "Signature";
$lng->{uifProfBlurb} = "Miscellaneous";
$lng->{uifProfAvat}  = "Avatar";
$lng->{uifBadges}    = "Badges";
$lng->{uifGrpMbrTtl} = "Groups";
$lng->{uifBrdSubTtl} = "Board Subscriptions";
$lng->{uifStatTtl}   = "Statistics";
$lng->{uifStatRank}  = "Rank";
$lng->{uifStatPNum}  = "Posts";
$lng->{uifStatPONum} = "posted";
$lng->{uifStatPENum} = "existing";
$lng->{uifStatRegTm} = "Registered";
$lng->{uifStatLOTm}  = "Last Online";
$lng->{uifStatLRTm}  = "Prev. Online";
$lng->{uifStatLIp}   = "Last IP";
$lng->{uifMapTtl}    = "Map";
$lng->{uifMapOthrMt} = "other matches";

# User list page
$lng->{uliTitle}     = "User List";
$lng->{uliLfmTtl}    = "List Format";
$lng->{uliLfmSearch} = "Search";
$lng->{uliLfmField}  = "View";
$lng->{uliLfmSort}   = "Sort";
$lng->{uliLfmSrtNam} = "Username";
$lng->{uliLfmSrtUid} = "User ID";
$lng->{uliLfmSrtFld} = "View";
$lng->{uliLfmOrder}  = "Order";
$lng->{uliLfmOrdAsc} = "Asc";
$lng->{uliLfmOrdDsc} = "Desc";
$lng->{uliLfmHide}   = "Hide empty";
$lng->{uliLfmListB}  = "List";
$lng->{uliLstName}   = "Username";

# User login page
$lng->{lgiTitle}     = "User";
$lng->{lgiLoginTtl}  = "Login";
$lng->{lgiLoginT}    = "If you don't have an account yet, you can <a href='[[regUrl]]'>register</a> one. If you just registered an account, you should receive the password by email (check your spam folder, too).";
$lng->{lgiLoginName} = "Username (or email address)";
$lng->{lgiLoginPwd}  = "Password";
$lng->{lgiLoginRmbr} = "Remember me on this computer";
$lng->{lgiLoginB}    = "Login";
$lng->{lgiFpwTtl}    = "Forgot Password";
$lng->{lgiFpwT}      = "If you have lost your password, you can have a login ticket link sent to your registered email address.";
$lng->{lgiFpwEmail}  = "Email address";
$lng->{lgiFpwB}      = "Send";
$lng->{lgiFpwMlSbj}  = "Forgot Password";
$lng->{lgiFpwMlT}    = "Please visit the following ticket link to login without your password. You may then proceed to change your password to a new one.\n\nFor security reasons, the ticket link is only valid for one use and for a limited time. Also, only the last requested ticket link is valid, should you have requested more than one.";

# User OpenID login page
$lng->{oidTitle}     = "User";
$lng->{oidLoginTtl}  = "OpenID Login";
$lng->{oidLoginUrl}  = "OpenID URL";
$lng->{oidLoginRmbr} = "Remember me on this computer";
$lng->{oidLoginB}    = "Login";
$lng->{oidListTtl}   = "Accepted OpenID Providers";

# User registration page
$lng->{regTitle}     = "User";
$lng->{regRegTtl}    = "Register Account";
$lng->{regRegT}      = "If you already have an account, you can login on the <a href='[[logUrl]]'>login</a> page, where you can also replace lost passwords.";
$lng->{regRegName}   = "Username";
$lng->{regRegEmail}  = "Email Address (login password will be sent to this address)";
$lng->{regRegEmailV} = "Repeat Email Address";
$lng->{regRegPwd}    = "Password";
$lng->{regRegPwdFmt} = "min. 8 characters";
$lng->{regRegPwdV}   = "Repeat Password";
$lng->{regRegB}      = "Register";
$lng->{regMailSubj}  = "Registration";
$lng->{regMailT}     = "You have registered a forum account.";
$lng->{regMailName}  = "Username: ";
$lng->{regMailPwd}   = "Password: ";
$lng->{regMailT2}    = "After you have logged in using the link or manually using the username and password, please go to Options/Password and change the password to something more memorable.";

# User profile and options pages
$lng->{uopTitle}     = "User";
$lng->{uopPasswd}    = "Password";
$lng->{uopPasswdTT}  = "Change password";
$lng->{uopName}      = "Name";
$lng->{uopNameTT}    = "Change username";
$lng->{uopEmail}     = "Email";
$lng->{uopEmailTT}   = "Change email address";
$lng->{uopGroups}    = "Groups";
$lng->{uopGroupsTT}  = "Join or leave groups";
$lng->{uopBoards}    = "Boards";
$lng->{uopBoardsTT}  = "Configure board options";
$lng->{uopTopics}    = "Topics";
$lng->{uopTopicsTT}  = "Configure topic options";
$lng->{uopAvatar}    = "Avatar";
$lng->{uopAvatarTT}  = "Select avatar image";
$lng->{uopBadges}    = "Badges";
$lng->{uopBadgesTT}  = "Select badges";
$lng->{uopIgnore}    = "Ignore";
$lng->{uopIgnoreTT}  = "Ignore other users";
$lng->{uopWatch}     = "Watch";
$lng->{uopWatchTT}   = "Manage watched words and users";
$lng->{uopOpenPgp}   = "OpenPGP";
$lng->{uopOpenPgpTT} = "Configure email encryption options";
$lng->{uopInfo}      = "Info";
$lng->{uopInfoTT}    = "Show user info";
$lng->{uopProfTtl}   = "Profile";
$lng->{uopProfRName} = "Real Name";
$lng->{uopProfBdate} = "Birthday (YYYY-MM-DD or MM-DD)";
$lng->{uopProfPage}  = "Website";
$lng->{uopProfOccup} = "Occupation";
$lng->{uopProfHobby} = "Hobbies";
$lng->{uopProfLocat} = "Geographic Location";
$lng->{uopProfLocIn} = "[Insert]";
$lng->{uopProfIcq}   = "Email/Messengers";
$lng->{uopProfSig}   = "Signature";
$lng->{uopProfSigLt} = "(max. 100 characters, 2 lines)";
$lng->{uopProfBlurb} = "Miscellaneous";
$lng->{uopOptTtl}    = "Options";
$lng->{uopPrefPrivc} = "Privacy (hide online status and IP-based location, only show info page to reg. users)";
$lng->{uopPrefNtMsg} = "Receive reply and message notifications by email, too";
$lng->{uopPrefNt}    = "Receive reply notifications";
$lng->{uopDispLang}  = "Language";
$lng->{uopDispTimeZ} = "Timezone";
$lng->{uopDispTimeS} = "Server";
$lng->{uopDispStyle} = "Style";
$lng->{uopDispFFace} = "Font Face";
$lng->{uopDispFSize} = "Font Size (in pixels, 0 = default)";
$lng->{uopDispIndnt} = "Indent (1-10%, for post threading)";
$lng->{uopDispTpcPP} = "Topics Per Page (0 = use allowed maximum)";
$lng->{uopDispPstPP} = "Posts Per Page (0 = use allowed maximum)";
$lng->{uopDispDescs} = "Show board descriptions";
$lng->{uopDispDeco}  = "Show decoration (user titles, badges, ranks etc.)";
$lng->{uopDispAvas}  = "Show avatars";
$lng->{uopDispImgs}  = "Show embedded images and videos";
$lng->{uopDispSigs}  = "Show signatures";
$lng->{uopDispColl}  = "Collapse topic branches without new/unread posts";
$lng->{uopSubmitB}   = "Change";

# User password page
$lng->{pwdTitle}     = "User";
$lng->{pwdChgTtl}    = "Change Password";
$lng->{pwdChgT}      = "Never use the same password for multiple accounts.";
$lng->{pwdChgPwd}    = "Password";
$lng->{pwdChgPwdFmt} = "min. 8 characters";
$lng->{pwdChgPwdV}   = "Repeat Password";
$lng->{pwdChgB}      = "Change";

# User name page
$lng->{namTitle}     = "User";
$lng->{namChgTtl}    = "Change Username";
$lng->{namChgT}      = "Due to the confusion caused by name changes, please only use this function for a good reason (e.g. fixing a spelling mistake, unifying the names of multiple online accounts or changing silly names after growing up).";
$lng->{namChgT2}     = "You can rename yourself <em>[[times]]</em> more times.";
$lng->{namChgName}   = "Username";
$lng->{namChgB}      = "Change";

# User email page
$lng->{emlTitle}     = "User";
$lng->{emlChgTtl}    = "Email Address";
$lng->{emlChgT}      = "A new or changed email address will only take effect once you have reacted to the verification email sent to that address.";
$lng->{emlChgAddr}   = "Email Address";
$lng->{emlChgAddrV}  = "Repeat Email Address";
$lng->{emlChgB}      = "Change";
$lng->{emlChgMlSubj} = "Email Address Change";
$lng->{emlChgMlT}    = "You have requested a change of your forum account's email address. To ensure the validity of the address, your account will only be updated once you have visited the following ticket link:";

# User group options page
$lng->{ugrTitle}     = "User";
$lng->{ugrGrpStTtl}  = "Group Membership";
$lng->{ugrGrpStAdm}  = "Admin";
$lng->{ugrGrpStMbr}  = "Member";
$lng->{ugrSubmitTtl} = "Change Group Membership";
$lng->{ugrChgB}      = "Change";

# User board options page
$lng->{ubdTitle}     = "User";
$lng->{ubdSubsT2}    = "Instant subscriptions send out new posts in the selected board to you by email instantly. Digest subscriptions send out collected posts regularly (usually daily).";
$lng->{ubdBrdStTtl}  = "Board Options";
$lng->{ubdBrdStSubs} = "Email Subscription";
$lng->{ubdBrdStInst} = "Instant";
$lng->{ubdBrdStDig}  = "Digest";
$lng->{ubdBrdStOff}  = "Off";
$lng->{ubdBrdStHide} = "Hide";
$lng->{ubdSubmitTtl} = "Change Board Options";
$lng->{ubdChgB}      = "Change";

# User topic options page
$lng->{utpTitle}     = "User";
$lng->{utpTpcStTtl}  = "Topic Options";
$lng->{utpTpcStSubs} = "Email Subscription";
$lng->{ubdTpcStInst} = "Instant";
$lng->{ubdTpcStDig}  = "Digest";
$lng->{ubdTpcStOff}  = "Off";
$lng->{utpEmpty}     = "No topics with enabled options found.";
$lng->{utpSubmitTtl} = "Change Topic Options";
$lng->{utpChgB}      = "Change";

# Avatar page
$lng->{avaTitle}     = "User";
$lng->{avaUplTtl}    = "Custom Avatar";
$lng->{avaUplImgExc} = "JPG/PNG/GIF image (no animation, max. file size [[size]], exact dimensions [[width]]x[[height]] pixels)";
$lng->{avaUplImgRsz} = "JPG/PNG/GIF image (no animation, max. file size [[size]])";
$lng->{avaUplUplB}   = "Upload";
$lng->{avaUplDelB}   = "Delete";
$lng->{avaGalTtl}    = "Avatar Gallery";
$lng->{avaGalSelB}   = "Select";
$lng->{avaGalDelB}   = "Unselect";
$lng->{avaGrvTtl}    = "Gravatar";
$lng->{avaGrvEmail}  = "Gravatar Email Address";
$lng->{avaGrvSelB}   = "Select";
$lng->{avaGrvDelB}   = "Unselect";

# User badges page
$lng->{bdgTitle}     = "User";
$lng->{bdgSelTtl}    = "Badges";
$lng->{bdgSubmitTtl} = "Select Badges";
$lng->{bdgSubmitB}   = "Select";

# User ignore page
$lng->{uigTitle}     = "User";
$lng->{uigAddT}      = "Private messages by ignored users will be silently discarded and posts will be hidden.";
$lng->{uigAddTtl}    = "Add User to Ignore List";
$lng->{uigAddUser}   = "Username";
$lng->{uigAddB}      = "Add";
$lng->{uigRemTtl}    = "Remove User from Ignore List";
$lng->{uigRemUser}   = "Username";
$lng->{uigRemB}      = "Remove";

# Watch word/user page
$lng->{watTitle}     = "User";
$lng->{watWrdAddTtl} = "Add Watched Word";
$lng->{watWrdAddT}   = "If a watched word gets mentioned in a new post, you will receive a notification.";
$lng->{watWrdAddWrd} = "Word";
$lng->{watWrdAddB}   = "Add";
$lng->{watWrdRemTtl} = "Remove Watched Word";
$lng->{watWrdRemWrd} = "Word";
$lng->{watWrdRemB}   = "Remove";
$lng->{watUsrAddTtl} = "Add Watched User";
$lng->{watUsrAddT}   = "If a watched user writes a new post, you will receive a notification.";
$lng->{watUsrAddUsr} = "Username";
$lng->{watUsrAddB}   = "Add";
$lng->{watUsrRemTtl} = "Remove Watched User";
$lng->{watUsrRemUsr} = "Username";
$lng->{watUsrRemB}   = "Remove";

# Group info page
$lng->{griTitle}     = "Group";
$lng->{griMembers}   = "Members";
$lng->{griMbrTtl}    = "Members";
$lng->{griBrdAdmTtl} = "Moderator Permissions";
$lng->{griBrdMbrTtl} = "Member Permissions";

# Group members page
$lng->{grmTitle}     = "Group";
$lng->{grmAddTtl}    = "Add Members";
$lng->{grmAddUser}   = "Usernames (separate with semicolons if using text input)";
$lng->{grmAddB}      = "Add";
$lng->{grmRemTtl}    = "Remove Members";
$lng->{grmRemUser}   = "Username";
$lng->{grmRemB}      = "Remove";

# Board groups page
$lng->{bgrTitle}     = "Board";
$lng->{bgrPermTtl}   = "Permissions";
$lng->{bgrModerator} = "Moderator";
$lng->{bgrMember}    = "Member";
$lng->{bgrChangeTtl} = "Change Permissions";
$lng->{bgrChangeB}   = "Change";

# Board split page
$lng->{bspTitle}     = "Board";
$lng->{bspSplitTtl}  = "Split Board";
$lng->{bspSplitDest} = "Destination Board";
$lng->{bspSplitB}    = "Split";

# Topic tag page
$lng->{ttgTitle}     = "Topic";
$lng->{ttgTagTtl}    = "Tag Topic";
$lng->{ttgTagB}      = "Tag";

# Topic move page
$lng->{mvtTitle}     = "Topic";
$lng->{mvtMovTtl}    = "Move Topic";
$lng->{mvtMovDest}   = "Destination Board";
$lng->{mvtMovB}      = "Move";

# Topic merge page
$lng->{mgtTitle}     = "Topic";
$lng->{mgtMrgTtl}    = "Merge Topics";
$lng->{mgtMrgDest}   = "Destination Topic";
$lng->{mgtMrgDest2}  = "Alternative manual ID input (for older topics or topics in other boards)";
$lng->{mgtMrgB}      = "Merge";

# Branch page
$lng->{brnTitle}     = "Topic Branch";
$lng->{brnPromoTtl}  = "Promote to Topic";
$lng->{brnPromoSbj}  = "Subject";
$lng->{brnPromoBrd}  = "Board";
$lng->{brnPromoLink} = "Add crosslink posts";
$lng->{brnPromoB}    = "Promote";
$lng->{brnProLnkBdy} = "topic branch moved";
$lng->{brnMoveTtl}   = "Move";
$lng->{brnMovePrnt}  = "Parent post ID (can be in different topic, 0 = move to top level in this topic)";
$lng->{brnMoveB}     = "Move";
$lng->{brnLockTtl}   = "Lock";
$lng->{brnLockLckB}  = "Lock";
$lng->{brnLockUnlB}  = "Unlock";
$lng->{brnDeleteTtl} = "Delete";
$lng->{brnDeleteB}   = "Delete";

# Search page
$lng->{seaTitle}     = "Forum";
$lng->{seaTtl}       = "Search";
$lng->{seaAdvOpt}    = "More";
$lng->{seaBoard}     = "Board";
$lng->{seaBoardAll}  = "All boards";
$lng->{seaWords}     = "Words";
$lng->{seaWordsFtsT} = "Used fulltext search expression: <em>[[expr]]</em>";
$lng->{seaUser}      = "User";
$lng->{seaMinAge}    = "Min. Age";
$lng->{seaMaxAge}    = "Max. Age";
$lng->{seaField}     = "Field";
$lng->{seaFieldBody} = "Text";
$lng->{seaFieldRaw}  = "Raw Text";
$lng->{seaFieldSubj} = "Subject";
$lng->{seaOrder}     = "Order";
$lng->{seaOrderAsc}  = "Oldest first";
$lng->{seaOrderDesc} = "Newest first";
$lng->{seaB}         = "Search";
$lng->{seaGglTtl}    = "Search - powered by Google&trade;";
$lng->{serTopic}     = "Topic";
$lng->{serNotFound}  = "No matches found.";

# Help page
$lng->{hlpTitle}     = "Help";
$lng->{hlpTxtTtl}    = "Terms and Features";
$lng->{hlpFaqTtl}    = "Frequently Asked Questions";

# Message list page
$lng->{mslTitle}     = "Private Messages";
$lng->{mslSend}      = "Send";
$lng->{mslSendTT}    = "Send private message";
$lng->{mslExport}    = "Export";
$lng->{mslExportTT}  = "Export all private messages as one HTML file";
$lng->{mslDelAll}    = "Delete";
$lng->{mslDelAllTT}  = "Delete all read and sent private messages";
$lng->{mslInbox}     = "Inbox";
$lng->{mslOutbox}    = "Sent";
$lng->{mslFrom}      = "Sender";
$lng->{mslTo}        = "Recipient";
$lng->{mslDate}      = "Date";
$lng->{mslCommands}  = "Commands";
$lng->{mslDelete}    = "Delete";
$lng->{mslNotFound}  = "No private messages in this box.";
$lng->{mslExpire}    = "Private messages expire after [[days]] days.";

# Add message page
$lng->{msaTitle}     = "Private Message";
$lng->{msaSendTtl}   = "Send Private Message";
$lng->{msaSendRecv}  = "Recipient";
$lng->{msaSendRecvM} = "Recipients (separate up to [[maxRcv]] names with semicolons)";
$lng->{msaSendSbj}   = "Subject";
$lng->{msaSendTxt}   = "Message Text";
$lng->{msaSendB}     = "Send";
$lng->{msaSendPrvB}  = "Preview";
$lng->{msaPrvTtl}    = "Preview";
$lng->{msaRefTtl}    = "In Response to";
$lng->{msaEmailSbPf} = "Message from";
$lng->{msaEmailTSbj} = "Subject: ";
$lng->{msaEmailT2}   = "This is a message notification from the forum software.\nPlease don't reply to this email.";

# Message page
$lng->{mssTitle}     = "Private Message";
$lng->{mssDelete}    = "Delete";
$lng->{mssDeleteTT}  = "Delete message";
$lng->{mssReply}     = "Reply";
$lng->{mssReplyTT}   = "Reply to message";
$lng->{mssQuote}     = "Quote";
$lng->{mssQuoteTT}   = "Reply to message with quote";
$lng->{mssFrom}      = "From";
$lng->{mssTo}        = "To";
$lng->{mssDate}      = "Date";
$lng->{mssSubject}   = "Subject";

# Chat page
$lng->{chtTitle}     = "Chat";
$lng->{chtRefresh}   = "Refresh";
$lng->{chtRefreshTT} = "Refresh page";
$lng->{chtDelAll}    = "Delete All";
$lng->{chtDelAllTT}  = "Delete all messages";
$lng->{chtAddTtl}    = "Post Message";
$lng->{chtAddB}      = "Post";
$lng->{chtMsgsTtl}   = "Messages";

# Attachment list page
$lng->{aliTitle}     = "Attachment List";
$lng->{aliLfmTtl}    = "Search and Format";
$lng->{aliLfmWords}  = "Words";
$lng->{aliLfmUser}   = "User";
$lng->{aliLfmBoard}  = "Board";
$lng->{aliLfmField}  = "Field";
$lng->{aliLfmFldFnm} = "Filename";
$lng->{aliLfmFldCpt} = "Caption";
$lng->{aliLfmMinAge} = "Min. Age";
$lng->{aliLfmMaxAge} = "Max. Age";
$lng->{aliLfmOrder}  = "Order";
$lng->{aliLfmOrdAsc} = "Oldest first";
$lng->{aliLfmOrdDsc} = "Newest first";
$lng->{aliLfmGall}   = "Gallery";
$lng->{aliLfmListB}  = "List";
$lng->{aliLstFile}   = "Filename";
$lng->{aliLstCapt}   = "Caption";
$lng->{aliLstSize}   = "Size";
$lng->{aliLstPost}   = "Post";
$lng->{aliLstUser}   = "User";

# Feeds page
$lng->{fedTitle}     = "Feeds";
$lng->{fedAllBoards} = "All public boards";

# Email subscriptions
$lng->{subSubjBrdIn} = "Board instant subscription";
$lng->{subSubjTpcIn} = "Topic instant subscription";
$lng->{subSubjBrdDg} = "Board digest subscription";
$lng->{subSubjTpcDg} = "Topic digest subscription";
$lng->{subNoReply}   = "This is a subscription email from the forum software.\nPlease don't reply to this email.";
$lng->{subLink}      = "Link: ";
$lng->{subBoard}     = "Board: ";
$lng->{subTopic}     = "Topic: ";
$lng->{subBy}        = "User: ";
$lng->{subOn}        = "Date: ";
$lng->{subUnsubBrd}  = "Unsubscribe from this board:";
$lng->{subUnsubTpc}  = "Unsubscribe from this topic:";

# Bounce detection
$lng->{bncWarning}   = "Warning: either your email account doesn't exist anymore, rejects emails, or spams with automatic replies. Please rectify this situation, or the forum may have to stop sending email to you.";

# Confirmation
$lng->{cnfTitle}     = "Confirmation";
$lng->{cnfDelAllMsg} = "Do you really want to delete all read messages?";
$lng->{cnfDelAllCht} = "Do you really want to delete all chat messages?";
$lng->{cnfDelAllAtt} = "Do you really want to delete all attachments?";
$lng->{cnfQuestion}  = "Do you really want to delete";
$lng->{cnfQuestion2} = "?";
$lng->{cnfTypeUser}  = "user";
$lng->{cnfTypeGroup} = "group";
$lng->{cnfTypeCateg} = "category";
$lng->{cnfTypeBoard} = "board";
$lng->{cnfTypeTopic} = "topic";
$lng->{cnfTypePoll}  = "poll";
$lng->{cnfTypePost}  = "post";
$lng->{cnfTypeMsg}   = "message";
$lng->{cnfDeleteB}   = "Delete";

# Notification messages
$lng->{notNotify}    = "Notify user (optionally specify reason)";
$lng->{notReason}    = "Reason:";
$lng->{notMsgAdd}    = "[[usrNam]] sent a private <a href='[[msgUrl]]'>message</a>.";
$lng->{notPstAdd}    = "[[usrNam]] replied to a <a href='[[pstUrl]]'>post</a>.";
$lng->{notPstPng}    = "[[usrNam]] has notified you about a <a href='[[pstUrl]]'>post</a>.";
$lng->{notPstEdt}    = "A moderator edited a <a href='[[pstUrl]]'>post</a>.";
$lng->{notPstDel}    = "A moderator deleted a <a href='[[tpcUrl]]'>post</a>.";
$lng->{notTpcMov}    = "A moderator moved a <a href='[[tpcUrl]]'>topic</a>.";
$lng->{notTpcDel}    = "A moderator deleted a topic titled \"[[tpcSbj]]\".";
$lng->{notTpcMrg}    = "A moderator merged a topic into another <a href='[[tpcUrl]]'>topic</a>.";
$lng->{notEmlReg}    = "Welcome, [[usrNam]]! To enable email-based features, please enter your <a href='[[emlUrl]]'>email address</a>.";
$lng->{notOidRen}    = "As it wasn't possible to automatically assign you a short username, you may optionally <a href='[[namUrl]]'>rename</a> yourself.";
$lng->{notWatWrd}    = "Watched word \"[[watWrd]]\" was mentioned in a <a href='[[pstUrl]]'>post</a>.";
$lng->{notWatUsr}    = "Watched user \"[[watUsr]]\" wrote a <a href='[[pstUrl]]'>post</a>.";
$lng->{notThrStr}    = "You seem to have replied to the wrong <a href='[[pstUrl]]'>post</a>. Please use the specific Reply button of the post that you are referencing, not just any random Reply button. This is important to preserve the threaded tree structure of topics, and also makes sure that reply notifications go to the right person. If you want to reply to a topic in general without referencing a specific post, use the topic-level Post button near the top and bottom of the page.";

# Execution messages
$lng->{msgReplyPost} = "Reply posted";
$lng->{msgNewPost}   = "New topic posted";
$lng->{msgPstChange} = "Post changed";
$lng->{msgPstDel}    = "Post deleted";
$lng->{msgPstTpcDel} = "Post and topic deleted";
$lng->{msgPstApprv}  = "Post approved";
$lng->{msgPstAttach} = "Attachment(s) added";
$lng->{msgPstDetach} = "Attachment(s) deleted";
$lng->{msgPstAttChg} = "Attachment changed";
$lng->{msgEmlChange} = "Verification email sent";
$lng->{msgPrfChange} = "Profile changed";
$lng->{msgOptChange} = "Options changed";
$lng->{msgPwdChange} = "Password changed";
$lng->{msgNamChange} = "Username changed";
$lng->{msgAvaChange} = "Avatar changed";
$lng->{msgBdgChange} = "Badges changed";
$lng->{msgGrpChange} = "Group memberships changed";
$lng->{msgBrdChange} = "Board options changed";
$lng->{msgTpcChange} = "Topic options changed";
$lng->{msgAccntReg}  = "Account registered";
$lng->{msgAccntRegM} = "Account registered. Please wait for the email with your password to arrive before proceeding to login. The email may end up in your spam folder, and anti-spam measures may delay it for some time.";
$lng->{msgMemberAdd} = "Member(s) added";
$lng->{msgMemberRem} = "Member(s) removed";
$lng->{msgTpcDelete} = "Topic deleted";
$lng->{msgTpcStik}   = "Topic changed to sticky";
$lng->{msgTpcUnstik} = "Topic changed to not sticky";
$lng->{msgTpcLock}   = "Topic locked";
$lng->{msgTpcUnlock} = "Topic unlocked";
$lng->{msgTpcMove}   = "Topic moved";
$lng->{msgTpcMerge}  = "Topics merged";
$lng->{msgBrnPromo}  = "Branch promoted";
$lng->{msgBrnMove}   = "Branch moved";
$lng->{msgBrnDelete} = "Branch deleted";
$lng->{msgPstAddRep} = "Post reported";
$lng->{msgPstRemRep} = "Report deleted";
$lng->{msgMarkOld}   = "Posts marked as old";
$lng->{msgMarkRead}  = "Posts marked as read";
$lng->{msgPollAdd}   = "Poll added";
$lng->{msgPollDel}   = "Poll deleted";
$lng->{msgPollLock}  = "Poll closed";
$lng->{msgPollVote}  = "Voted";
$lng->{msgMsgAdd}    = "Private message sent";
$lng->{msgMsgDel}    = "Private message(s) deleted";
$lng->{msgChatAdd}   = "Chat message added";
$lng->{msgChatDel}   = "Chat message(s) deleted";
$lng->{msgIgnoreAdd} = "Ignored user added";
$lng->{msgIgnoreRem} = "Ignored user removed";
$lng->{msgWatWrdAdd} = "Watched word added";
$lng->{msgWatWrdRem} = "Watched word removed";
$lng->{msgWatUsrAdd} = "Watched user added";
$lng->{msgWatUsrRem} = "Watched user removed";
$lng->{msgTksFgtPwd} = "Email sent";
$lng->{msgTkaFgtPwd} = "Logged in. You may now change your password.";
$lng->{msgTkaEmlChg} = "Email address changed";
$lng->{msgTpcTag}    = "Topic tagged";
$lng->{msgTpcSub}    = "Topic subscribed";
$lng->{msgTpcUnsub}  = "Topic unsubscribed";
$lng->{msgBrdUnsub}  = "Board unsubscribed";
$lng->{msgNotesDel}  = "Notifications deleted";
$lng->{msgPstLock}   = "Post locked";
$lng->{msgPstUnlock} = "Post unlocked";
$lng->{msgPstPing}   = "Post notification sent";

# Error messages
$lng->{errDefault}   = "[error string missing]";
$lng->{errParamMiss} = "Mandatory parameter is missing.";
$lng->{errCatNotFnd} = "Category doesn't exist.";
$lng->{errBrdNotFnd} = "Board doesn't exist.";
$lng->{errTpcNotFnd} = "Topic doesn't exist.";
$lng->{errPstNotFnd} = "Post doesn't exist.";
$lng->{errAttNotFnd} = "Attachment doesn't exist.";
$lng->{errMsgNotFnd} = "Message doesn't exist.";
$lng->{errUsrNotFnd} = "User doesn't exist.";
$lng->{errGrpNotFnd} = "Group doesn't exist.";
$lng->{errTktNotFnd} = "Ticket doesn't exist. Tickets only work once, expire after two days, and only the most recently requested ticket is valid.";
$lng->{errUnsNotFnd} = "Subscription code doesn't exist.";
$lng->{errUsrDel}    = "User account doesn't exist anymore.";
$lng->{errUsrFake}   = "Not a real user account.";
$lng->{errSubEmpty}  = "Subject is empty.";
$lng->{errBdyEmpty}  = "Text is empty.";
$lng->{errNamEmpty}  = "Username is empty.";
$lng->{errPwdEmpty}  = "Password is empty.";
$lng->{errEmlEmpty}  = "Email address is empty.";
$lng->{errEmlInval}  = "Email address is invalid.";
$lng->{errNamSize}   = "Username is too short or too long.";
$lng->{errPwdSize}   = "Password needs to have at least 8 characters.";
$lng->{errEmlSize}   = "Email address is too short or too long.";
$lng->{errNamChar}   = "Username contains illegal characters.";
$lng->{errPwdChar}   = "Password contains illegal characters.";
$lng->{errPwdWrong}  = "Password is wrong.";
$lng->{errNoAccess}  = "Access denied.";
$lng->{errBannedT}   = "You have been banned. Reason:";
$lng->{errBannedT2}  = "Duration: ";
$lng->{errBannedT3}  = "days.";
$lng->{errBlockEmlT} = "Your email domain is on the forum's blacklist.";
$lng->{errBlockIp}   = "Your IP address is on the forum's blacklist.";
$lng->{errSubLen}    = "Max. subject length exceeded.";
$lng->{errBdyLen}    = "Max. text length exceeded.";
$lng->{errOptLen}    = "Max. option length exceeded.";
$lng->{errTpcLocked} = "Topic is locked.";
$lng->{errPstLocked} = "Post is locked.";
$lng->{errSubNoText} = "Subject doesn't contain any real text.";
$lng->{errNamGone}   = "Username is already registered.";
$lng->{errNamResrvd} = "Username contains reserved text.";
$lng->{errEmlGone}   = "Email address is already registered. Only one account per address.";
$lng->{errPwdDiffer} = "Passwords differ.";
$lng->{errEmlDiffer} = "Email addresses differ.";
$lng->{errDupe}      = "This post has already been posted.";
$lng->{errAttName}   = "No file or filename specified.";
$lng->{errAttSize}   = "Upload is missing, was truncated or exceeds maximum allowed size.";
$lng->{errPromoTpc}  = "This post is the base post for the whole topic.";
$lng->{errPstEdtTme} = "Posts may only be edited a limited time after their original submission. This time limit has expired.";
$lng->{errDontEmail} = "Sending of email for your account has been disabled. Typical reasons are invalid email addresses, jammed mailboxes and activated autoresponders.";
$lng->{errEditAppr}  = "You can't edit posts in a moderated board anymore once they're approved.";
$lng->{errRepDupe}   = "You have already reported this post.";
$lng->{errRepReason} = "Reason field is empty.";
$lng->{errSrcAuth}   = "Request source authentication failed. Either someone tried tricking you into doing something that you didn't want to do (if you came to this page from a different site), or you left a forum page open for too long.";
$lng->{errPolExist}  = "Topic already has a poll.";
$lng->{errPolOptNum} = "Poll has too few or too many options.";
$lng->{errPolNoDel}  = "Only polls without votes can be deleted.";
$lng->{errPolNoOpt}  = "No option selected.";
$lng->{errPolNotFnd} = "Poll doesn't exist.";
$lng->{errPolLocked} = "Poll is closed.";
$lng->{errPolOpNFnd} = "Poll option doesn't exist.";
$lng->{errPolVotedP} = "You have already voted in this poll.";
$lng->{errAvaSizeEx} = "Maximum file size exceeded.";
$lng->{errAvaDimens} = "Image must have specified width and height.";
$lng->{errAvaFmtUns} = "File format unsupported or invalid.";
$lng->{errAvaNoAnim} = "Animated images are not allowed.";
$lng->{errRepostTim} = "Flood control enabled. You have to wait [[seconds]] seconds before you can post again.";
$lng->{errCrnEmuBsy} = "The forum is currently busy with maintenance tasks. Please come back later.";
$lng->{errForumLock} = "The forum is currently locked. Please come back later.";
$lng->{errMinRegTim} = "You need to be registered for at least [[hours]] hour(s) before you can use this feature.";
$lng->{errDbHidden}  = "A database error has occurred and was logged.";
$lng->{errCptTmeOut} = "Anti-spam image timed out, you have [[seconds]] seconds to submit the form.";
$lng->{errCptWrong}  = "Characters from the anti-spam image are not correct. Please try again.";
$lng->{errCptFail}   = "You failed the anti-spam test.";
$lng->{errOidEmpty}  = "OpenID URL is empty.";
$lng->{errOidLen}    = "OpenID URL is too long.";
$lng->{errOidPrNtAc} = "OpenID provider is not on the list of accepted providers.";
$lng->{errOidNotFnd} = "OpenID URL or provider not found.";
$lng->{errOidCancel} = "OpenID verification cancelled by user.";
$lng->{errOidReplay} = "OpenID replay attack detected.";
$lng->{errOidFail}   = "OpenID verification failed.";
$lng->{errWordSize}  = "Word is too short or too long.";
$lng->{errWordChar}  = "Word contains illegal characters.";
$lng->{errWatchNum}  = "Maximum number of watch entries used.";
$lng->{errFgtPwdDuh} = "You have already used this function recently or you have only just registered. Please wait for the email to arrive, and make sure to also check your spam folder.";
$lng->{errRecvNum}   = "Too many recipients.";
$lng->{errOldAgent}  = "Your browser is severely outdated and is not supported by this forum anymore. Please get a <a href='http://abetterbrowser.org/'>better browser</a>.";
$lng->{errUAFeatSup} = "Your browser doesn't support this feature.";
$lng->{errNoCookies} = "Login won't work because browser cookies are disabled.";
$lng->{errSearchLnk} = "Linked search results are disabled.";


#------------------------------------------------------------------------------
# Help

$lng->{help} = "

<p>Note: as the mwForum software is highly configurable, not all of the features 
mentioned below are necessarily enabled in this installation.</p>

<h3>Forum</h3>

<p>The forum is the whole installation, and usually contains multiple boards. 
You should always enter the forum through a link that ends in \"forum.pl\" (not 
\"forum_show.pl\") to let the forum know when you start a new session. Otherwise 
the forum won't know when to display posts as new or old.</p>

<h3>User</h3>

<p>A user is anyone who registers an account in the forum. Registration is 
usually not required for reading most boards, but depending on configuration 
only registered users will have access to certain boards and features.</p>

<h3>Group</h3>

<p>Users can be granted membership in user groups. Open groups can also be 
joined by users themselves. The groups in turn are granted member or moderator 
rights in selected boards, allowing members of the group to read and write in or 
moderate those boards.</p>

<h3>Board</h3>

<p>A board contains topics, which in turn contain the posts. Boards can be set 
to be visible to registered users or to moderators and board members only. 
Boards can optionally allow posts by unregistered guests. Announcement boards 
can be read-only, so that they only allow posts by moderators and members, or 
reply-only, which means that only moderators and members can start new topics, 
but everybody can reply. Another option for boards is moderation. If this option 
is activated, new posts will be invisible to normal users until a moderator 
approves them.</p>

<h3>Topic</h3>

<p>A topic, otherwise known as thread, contains all the posts on a specific 
subtopic, that should be named in the topic's subject. Boards have expiration 
values that determine after how many days their topics will expire or get locked 
after their last post has been made. Moderators can also manually lock topics, 
so that no replies can be made and no post can be edited anymore.</p>

<h3>Post</h3>

<p>A post is a public message by a user. It can be either a base post, which 
starts a new topic, or a reply to an existing topic. Posts can be edited and 
deleted, which may be limited to a certain time frame. Posts can be locked by 
moderators, making it impossible to reply or edit. Posts can be reported to the 
moderators in case of rule violations.</p>

<h3>Private Message</h3>

<p>In addition to the more or less public posts, private messages may be enabled 
in a forum. Registered users can send each other these messages without knowing 
the email addresses of the recipients.</p>

<h3>Administrator</h3>

<p>Administrators can control and edit everything in the forum. This means they 
can also act as moderators globally. Administrators are listed on the forum info 
page.</p>

<h3>Moderator</h3>

<p>Moderators' powers are limited to specific boards. They can edit, lock, 
delete and approve posts, lock and delete topics, and check the list of posts 
reported for rule violations. The user groups whose members have moderator 
rights in a board are listed on the board's info page.</p>

<h3>Polls</h3>

<p>The creator of a topic may be able to add a poll to that topic. Each poll can 
contain up to 20 options. Polls can allow one vote per registered users per 
poll, or alternatively multiple votes for different options at different points 
in time. Polls can't be edited, and can only be deleted as long as there haven't 
been any votes.</p>

<h3>Icons</h3>

<table>
<tr><td>
<img class='sic sic_post_nu' src='[[dataPath]]/epx.png' alt='N/U'>
<img class='sic sic_topic_nu' src='[[dataPath]]/epx.png' alt='N/U'>
<img class='sic sic_board_nu' src='[[dataPath]]/epx.png' alt='N/U'>
</td><td>
Yellow icons indicate new posts or topics and boards with new posts.
In this forum, \"new\" means a post has been added since your last visit. Even
if you have just read it, it is still a new post, and will only be counted as
old on your next visit to the forum.
</td></tr>
<tr><td>
<img class='sic sic_post_or' src='[[dataPath]]/epx.png' alt='O/R'>
<img class='sic sic_topic_or' src='[[dataPath]]/epx.png' alt='O/R'>
<img class='sic sic_board_or' src='[[dataPath]]/epx.png' alt='O/R'>
</td><td>
Checkmarked icons indicate that the post or all posts in a topic or
board have been read. Posts are counted as read once their topic had been on
screen or if they're older than a set number of days. Since new/old and
unread/read are independent concepts in this forum, posts can be new and read
as well as old and unread at the same time.
</td></tr>
<tr><td>
<img class='sic sic_post_i' src='[[dataPath]]/epx.png' alt='I'>
</td><td>
Indicates posts or topics that are invisible to other users, because they 
are waiting for approval by a moderator.
</td></tr>
<tr><td>
<img class='sic sic_topic_l' src='[[dataPath]]/epx.png' alt='L'>
</td><td>
Indicates posts or topics that have been locked. No replies or edits are 
possible anymore.
</td></tr>
</table>

<h3>Markup Tags</h3>

<p>For security reasons, mwForum only supports its own set of markup tags, no 
HTML tags. Available markup tags:</p>

<table>
<tr><td>[b]text[/b]</td>
<td>renders text <b>bold</b></td></tr>
<tr><td>[i]text[/i]</td>
<td>renders text <i>italic</i></td></tr>
<tr><td>[tt]text[/tt]</td>
<td>renders text <code>nonproportional</code></td></tr>
<tr><td>[url]address[/url]</td>
<td>links to the address</td></tr>
<tr><td>[url=address]text[/url]</td>
<td>links to the address with the given text</td></tr>
<tr><td>[img]address[/img]</td>
<td>embeds a remote image (if enabled)</td></tr>
<tr><td>[img]filename[/img]</td>
<td>embeds an attached image</td></tr>
<tr><td>[img thb]filename[/img]</td>
<td>embeds an attached image's thumbnail (if available)</td></tr>
</table>

<h3>Quoting</h3>

<p>mwForum uses email-style quoting. To quote someone, simply copy&amp;paste a 
line of text from the original post and prefix it with a &gt; sign. It will then 
get highlighted in a different color. Please don't quote more text than 
necessary to establish context. Some forums may also have automatic quoting 
enabled, in that case please also trim down the quoted text to a minimum.</p>

<h3>Keyboard Navigation</h3>

<p>Posts on topic pages of threaded boards can be navigated with the WASD keys 
in the same way as typical tree view controls can be navigated with the cursor 
keys. In addition, the E key jumps to the next new or unread post.</p>

";

#------------------------------------------------------------------------------
# FAQ

$lng->{faq} = "

<h3>Why don't old posts get displayed as old?</h3>

<p>You have to enter the forum through a link that ends in \"forum.pl\" (not 
\"forum_show.pl\") to let the forum know when you want to start a new session. 
Should you for whatever reason want to continue an old session without having 
posts marked as old, you can enter directly through \"forum_show.pl\".</p>

<h3>I lost my password, can you send it to me?</h3>

<p>The original password isn't stored anywhere for security reasons. But on the 
login page you can request an email with a ticket link that is valid for a 
limited time. After using that link to login, you can set a new password.</p>

<h3>Do I have to logout after a session?</h3>

<p>You only need to logout if you are using a computer that is also used by
other non-trusted persons. mwForum stores your user ID and password via
cookies on your computer, and these are removed on logout.</p>

<h3>How do I attach images and other files to posts?</h3>

<p>If attachments are enabled in the forum and the specific board you want to 
post in, first submit your post without the attachment, after that you can 
click the post's Attach button to go to the upload page. Posting and uploading 
is separated this way because uploads can fail for various reasons, and you 
probably don't want to lose your post text when that happens.</p>

";

#------------------------------------------------------------------------------

# Load local string overrides
do 'MwfEnglishLocal.pm';

#------------------------------------------------------------------------------
# Return OK
1;
