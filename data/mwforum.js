/*jslint browser: true, onevar: true, undef: true, nomen: true, eqeqeq: true,
  plusplus: true, bitwise: true, regexp: true, newcap: true, immed: true */
/*global $, window, document, navigator, google */

/* mwForum - Web-based discussion forum | Copyright 1999-2012 Markus Wichitill */

var mwf = { p: $("#mwfjs").data("params") };

$(document).on("ready", function () {
	var script = mwf.p.env_script;
	if (mwf.p.cfg_boardJumpList) { mwf.initBoardList(); }
	if (mwf.p.tagButtons) { mwf.initTagButtons(); }
	if (script === "topic_show") {
		mwf.initToggleBranch();
		mwf.initMoveBranch();
		mwf.initRevealPost();
	}
	else if (script === "topic_add" || script === "post_add" || script === "post_edit") {
		mwf.initInsertRaw();
	}
	else if ((script === "user_login" || script === "user_openid") && !mwf.p.cfg_urlSessions) { 
		mwf.initCheckCookie();
	}
	else if (script === "post_attach") { mwf.initPostAttach(); }
	else if (script === "attach_show") { mwf.initShowAttach(); }
	else if (script === "user_profile") { mwf.initGeolocate(); }
	else if (script === "user_info") { mwf.initGoogleMaps(); }
	else if (script === "forum_activity") { mwf.initActivityGraph(); }
	mwf.initDataVersion();
});

$(window).on("load", function () {
	if (mwf.p.env_script === "topic_show") { mwf.initTopicNavigation(); }
	else if (!("autofocus" in document.createElement("input"))) { $(".fcs:first").focus(); }
});

mwf.navigate = function (href) {
	if (mwf.navigating) { return; }
	mwf.navigating = true;
	window.location = href;
};

mwf.initBoardList = function () {
	$("form.bjp select").on("change", function () {
		var ext = mwf.p.m_ext,
			sid = mwf.p.m_sessionId ? "sid=" + mwf.p.m_sessionId : "",
			id = this.options[this.selectedIndex].value;
		if (id.indexOf("cid") === 0) { mwf.navigate("forum_show" + ext + "?" + sid + "#" + id); }
		else if (id === 0) { mwf.navigate("forum_show" + ext + "?" + sid); }
		else { mwf.navigate("board_show" + ext + "?" + "bid=" + id + ";" + sid); }
	});
};

mwf.toggleBranch = function (postId) {
	var tglObs = postId ? $("#tgl" + postId) : $(".tgl"),
		brnObs = postId ? $("#brn" + postId) : $(".brn");
	if (brnObs.is(":hidden")) {
		tglObs.removeClass("sic_nav_plus").addClass("sic_nav_minus");
		tglObs.attr({ title: mwf.p.lng_tpcBrnCollap, alt: "-" });
		if (postId) { brnObs.slideDown(); }
		else { brnObs.show(); }
	}
	else {
		tglObs.removeClass("sic_nav_minus").addClass("sic_nav_plus");
		tglObs.attr({ title: mwf.p.lng_tpcBrnExpand, alt: "+" });
		if (postId) { brnObs.slideUp(); }
		else { brnObs.hide(); }
	}
};

mwf.initToggleBranch = function () {
	$(".brn.clp").hide();
	$("body").on("click", ".tgl", function (ev) {
		if (ev.shiftKey) { mwf.toggleBranch(); }
		else { mwf.toggleBranch(this.id.substr(3)); }
	});
};

mwf.initMoveBranch = function () {
	var postId;
	if (!mwf.p.boardAdmin) { return; }
	$("body").on("click", ".frm.pst", function (ev) {
		if (ev.target.nodeName.toLowerCase() !== "div") { return; }
		if (ev.ctrlKey) {
			if (postId) { $("#pid" + postId + ", #brn" + postId).css("opacity", 1); }
			postId = this.id.substr(3);
			$("#pid" + postId + ", #brn" + postId).css("opacity", 0.5);
		}
		else if (ev.altKey && postId) {
			mwf.navigate("branch_move" + mwf.p.m_ext + "?pid=" + postId +
				";parent=" + this.id.substr(3) + ";auth=" + mwf.p.user_sourceAuth);
		}
	});
};

mwf.initRevealPost = function () {
	$("body").on("click", ".frm.pst.ign", function () {
		$(this).find(".bcl").show();
		$(this).find(".ccl").slideDown();
	});
};

mwf.initTopicNavigation = function () {
	var currPostOb, preHashPostOb;
	function scrollToPost (ob) {
		ob.parents(".brn:hidden").each(function () { mwf.toggleBranch(this.id.substr(3)); });
		ob.find(".psl").focus();
		window.scrollTo(0, ob.offset().top - 5);
	}
	$("body").on("focus", ".psl", function () {
		$(".pst.fcp").removeClass("fcp");
		currPostOb = $(this).closest(".pst");
		currPostOb.addClass("fcp");
	});
	$("body").on("click", ".prl, .nnl", function () {
		var ob = $(this),
			href = ob.attr("href");
		if (href.indexOf("#") !== 0) {
			window.location.hash = "#" + ob.closest(".pst").attr("id");
			return true;
		}
		if (ob.hasClass("prl")) { window.location.hash = href; }
		else { scrollToPost($(href)); }
		return false;
	});
	$(window).on("hashchange", function () {
		if (window.location.hash) { 
			if (!preHashPostOb) { preHashPostOb = currPostOb; }
			scrollToPost($(window.location.hash));
		}
		else if (preHashPostOb) {
			scrollToPost(preHashPostOb);
			preHashPostOb = null;
		}
	});
	if (window.location.hash) { scrollToPost($(window.location.hash)); }
	else if (mwf.p.scrollPostId) { scrollToPost($("#pid" + mwf.p.scrollPostId)); }
	else if (window.location.search.match(/\bfoc=last\b/)) { scrollToPost($(".pst:last")); }
	else { $(".psl:first").focus(); }
	$(document).on("keydown", function (ev) {
		var key, obs, ob, i, href;
		if (ev.ctrlKey || $(ev.target).is("input, textarea, select")) { return; }
		if (ev.which === 106) { mwf.toggleBranch(); }
		key = String.fromCharCode(ev.which);
		if (key === "W") {
			obs = $(".pst:visible");
			if ((i = obs.index(currPostOb)) > 0) {
				scrollToPost(obs.eq(i - 1));
			}
			else if ((obs = $(".sic_nav_prev")).length === 4) {
				mwf.navigate(obs.eq(1).parent().attr("href") + ";foc=last");
			}
		}
		else if (key === "S") {
			obs = $(".pst:visible");
			if ((i = obs.index(currPostOb)) >= 0 && i + 1 < obs.length) {
				scrollToPost(obs.eq(i + 1));
			}
			else if ((obs = $(".sic_nav_next")).length === 4) {
				mwf.navigate(obs.eq(1).parent().attr("href"));
			}
		}
		else if (key === "A") {
			if (currPostOb.next().is(".brn:visible")) {
				mwf.toggleBranch(currPostOb.attr("id").substr(3));
			}
			else if ((ob = currPostOb.find(".sic_nav_up")).length) {
				href = ob.parent().attr("href");
				if (href && href.indexOf("#") === 0) {
					scrollToPost($("#pid" + href.substr(4)));
				}
				else if (href) {
					mwf.navigate(href);
				}
			}
		}
		else if (key === "D") {
			if (currPostOb.next(".brn:hidden").length) {
				mwf.toggleBranch(currPostOb.attr("id").substr(3));
			}
			else if (currPostOb.next(".brn").length) {
				scrollToPost(currPostOb.next().find(".pst:first"));
			}
		}
		else if (key === "E") {
			if (currPostOb.is(".new, .unr")) {
				obs = $(".pst.new, .pst.unr");
				if ((i = obs.index(currPostOb)) >= 0 && i + 1 < obs.length) {
					scrollToPost(obs.eq(i + 1));
				}
				else if ((ob = currPostOb.find(".sic_post_nn")).length) {
					mwf.navigate(ob.parent().attr("href"));
				}
			}
			else {
				if ((ob = $(".pst.new, .pst.unr").first()).length) {
					scrollToPost(ob);
				}
				else if ((ob = $(".sic_post_nn:first")).length) {
					mwf.navigate(ob.parent().attr("href"));
				}
			}
		}
	});
};

mwf.insertTags = function (tag1, tag2) {
	var range, sel, scroll, start, end, before, after, caret,
		el = $(".tgi")[0];
	el.focus();
	if (document.selection) {
		range = document.selection.createRange();
		sel = range.text;
		range.text = tag2 ? "[" + tag1 + "]" + sel + "[/" + tag2 + "]" : ":" + tag1 + ":";
		range = document.selection.createRange();
		if (tag2 && !sel.length) { range.move("character", -tag2.length - 3); }
		else if (tag2) { range.move("character", tag1.length + 2 + sel.length + tag2.length + 3); }
		range.select();
	}
	else if (typeof el.selectionStart !== "undefined") {
		scroll = el.scrollTop;
		start = el.selectionStart;
		end = el.selectionEnd;
		before = el.value.substring(0, start);
		sel = el.value.substring(start, end);
		after = el.value.substring(end, el.textLength);
		el.value = tag2 ? before + "[" + tag1 + "]" + sel + "[/" + tag2 + "]" + after :
			before + ":" + tag1 + ":" + after;
		caret = sel.length === 0 ? start + tag1.length + 2 :
			start + tag1.length + 2 + sel.length + tag2.length + 3;
		el.selectionStart = caret;
		el.selectionEnd = caret;
		el.scrollTop = scroll;
	}
};

mwf.initTagButtons = function () {
	var html, selOb, btnOb,
		dlOb = $("#snippets");
	$(".tbb").on("click", ".tbt", function () {
		var match = this.id.match(/tbt_([a-z]+)(?:_([a-z]+))?/),
			tag1 = match[1],
			tag2 = tag1;
		if ($(this).hasClass("tbt_p")) { tag1 += "="; }
		else if (match[2]) { tag1 += "=" + match[2]; }
		mwf.insertTags(tag1, tag2);
	});
	$(".tbb").on("click", ".tbc", function () { mwf.insertTags(this.id.substr(4)); });
	if (!dlOb) { return; }
	html = "<option selected='selected' disabled='disabled'>" + mwf.p.lng_tbbInsSnip + "</option>";
	dlOb.children("dt").each(function () { html += "<option>" + $(this).text() + "</option>"; });
	selOb = $("<select size='1'>" + html + "</select>").insertAfter(dlOb);
	btnOb = $("<button type='button' class='snp'>+</button>").insertAfter(selOb);
	btnOb.on("click", function () {
		var start, end, before, after,
			name = selOb.find("option:selected").text(),
			text = dlOb.find("dt:contains(" + name + ")").next().text(),
			el = $(".tgi")[0];
		el.focus();
		if (document.selection) {
			document.selection.createRange().text = text;
		}
		else if (typeof el.selectionStart !== "undefined") {
			start = el.selectionStart;
			end = el.selectionEnd;
			before = el.value.substring(0, start);
			after = el.value.substring(end, el.textLength);
			el.value = before + text + after;
		}
	});
};

mwf.initInsertRaw = function () {
	$("#rawlnk").on("click", function () {
		$(this).hide();
		$("#rawfld").slideDown();
	});
};

mwf.initGeolocate = function () {
	if (mwf.p.cfg_userInfoMap < 1 || !navigator.geolocation) { return; }
	$("#loc").show().on("click", function () {
		navigator.geolocation.getCurrentPosition(function (p) {
			$("[name=location]").val(p.coords.latitude + " " + p.coords.longitude);
		});
	});
};

mwf.initGoogleMaps = function () {
	var map, viewport, geocoder,
		markers = [];
	if (!mwf.p.location) { return; }
	geocoder = new google.maps.Geocoder();
	geocoder.geocode({ address: mwf.p.location, country: mwf.p.countryCode,
		language: mwf.p.uaLangCode }, function (results, status) {
			var txt, i, result,
				mapOb = $("#map");
			if (status !== google.maps.GeocoderStatus.OK) {
				mapOb.closest(".frm").hide();
				return;
			}
			viewport = results[0].geometry.viewport;
			if (mwf.p.location.match(/^[\s\d\.\-]+$/)) { results = results.slice(0, 1); }
			if (results[0].formatted_address) {
				txt = results[0].formatted_address;
				if (results.length > 1) {
					txt += " (" + (results.length - 1) + " " + mwf.p.lng_uifMapOthrMt + ")";
				}
				$("#loc").append(txt);
			}
			map = new google.maps.Map(mapOb[0], { mapTypeId: google.maps.MapTypeId.ROADMAP,
				center: results[0].geometry.location, zoom: 4 });
			for (i = 0; (result = results[i]); i += 1) {
				markers.push(new google.maps.Marker({ map: map, position: result.geometry.location,
					title: result.formatted_address + " [" + result.geometry.location_type + "]" }));
			}
		}
	);
	$("#loc").on("click", function () { map.fitBounds(viewport); });
};

mwf.initDataVersion = function () {
	$(".cpr").on("dblclick", function () {
		$.post("ajax_dataversion" + mwf.p.m_ext, { foo: "bar" }, function (json) {
			$(".cpr:first").after("<p class='cpr'>" + (json.error || json.dataVersion) + "</p>");
		});
	});
};

mwf.initActivityGraph = function () {
	var y, yi, d, v, grad,
		canvasEl = $("canvas")[0],
		ctx = canvasEl.getContext("2d"),
		h = canvasEl.height,
		stats = $.parseJSON($("#postsPerDay").text());
	ctx.font = "9px sans-serif";
	ctx.textBaseline = "top";
	for (y = mwf.p.firstYear, yi = 0; y <= mwf.p.lastYear; y += 1, yi += 1) {
		ctx.fillStyle = "#f00";
		ctx.fillRect(yi * 365, 0, 1, h);
		ctx.fillText(y, yi * 365 + 3, 0);
		for (d = 0; d < 365; d += 1) {
			if ((v = stats[y + "." + d])) {
				grad = ctx.createLinearGradient(0, h - v, 0, h);
				grad.addColorStop(0, "#ccf");
				grad.addColorStop(1, "#00f");
				ctx.fillStyle = grad;
				ctx.fillRect(yi * 365 + d, h - v, 1, v);
			}
		}
	}
};

mwf.initCheckCookie = function () {
	$.get("ajax_checkcookie" + mwf.p.m_ext, {}, function (json) {
		if (!json.ok) { $("#cookieError").slideDown(); }
	});
};

mwf.initPostAttach = function () {
	var dragLeaveTimer,
		zoneOb = $("#dropZone"),
		fileOb = $("#upload [name=file]");
	if (!window.FormData) { return; }
	if ("draggable" in document.createElement("span")) { $("#dropNote").show(); }
	fileOb.prop("multiple", true);
	$("#upload").on("submit", function () {
		zoneOb.trigger("drop");
		return false;
	});
	$(document).on("dragover", function (ev) {
		ev.originalEvent.dataTransfer.dropEffect = "none";
	});
	zoneOb.on("dragenter", function () {
		zoneOb.addClass("drp");
		return false;
	});
	zoneOb.on("dragover", function (ev) {
		clearTimeout(dragLeaveTimer);
		ev.originalEvent.dataTransfer.dropEffect = "copy";
		return false;
	});
	zoneOb.on("dragleave", function (ev) {
		dragLeaveTimer = setTimeout(function () { zoneOb.removeClass("drp"); }, 200);
		return false;
	});
	zoneOb.on("drop", function (ev) {
		var i, file, files, size;
		zoneOb.removeClass("drp");
		if (ev.originalEvent) { files = ev.originalEvent.dataTransfer.files; }
		else { files = fileOb[0].files; }
		if (!files || !files.length) { return false; }
		zoneOb.off("dragenter").off("dragover").off("drop");
		zoneOb.children().hide();
		fileOb.remove();
		for (i = 0; (file = files[i]); i += 1) {
			size = Math.round(file.size / 1024) + "k";
			if (!file.size || file.size > mwf.p.maxAttachLen) { size = "<em>" + size + "</em>"; }
			zoneOb.append("<div>" + file.name + ", " + size + "<span id='prg" + i + "'></span></div>");
		}
		function nextFile (index) {
			var data, xhr,
				file = files[index],
				spanOb = $("#prg" + index);
			function error () {
				spanOb.html(", <em>Error</em>");
				nextFile(index + 1);
			}
			if (index >= files.length) {
				setTimeout(function () {
					mwf.navigate("post_attach" + mwf.p.m_ext + "?pid=" + mwf.p.postId); }, 1000);
				return;
			}
			if (!file.size || file.size > mwf.p.maxAttachLen) {
				nextFile(index + 1);
				return;
			}
			data = new window.FormData($("#upload")[0]);
			data.append("ajax", 1);
			data.append("file", file);
			xhr = new window.XMLHttpRequest();
			xhr.open("POST", "post_attach" + mwf.p.m_ext, true);
			xhr.addEventListener("error", error, false);
			xhr.addEventListener("abort", error, false);
			xhr.addEventListener("load", function () {
				var json;
				try { json = $.parseJSON(xhr.responseText); } catch (x) {}
				if (json) { 
					spanOb.html(", " + (json.ok ? "100%" : "<em>" + json.error + "</em>")); 
					nextFile(index + 1);
				}
				else { error(); }
			}, false);
			xhr.upload.addEventListener("progress", function (ev) {
				spanOb.html(", <b>" + Math.round((ev.loaded * 100) / ev.total) + "%</b>");
			}, false);
			xhr.send(data);
		}
		nextFile(0);
		return false;
	});
};

mwf.initShowAttach = function () {
	var imgOb = $("p.ims img");
	imgOb.on("click", function () {
		if (imgOb[0].style.width !== "100%") { imgOb.width("100%"); }
		else { imgOb.width("auto"); }
	});
};
