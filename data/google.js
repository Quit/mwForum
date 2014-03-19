/*jslint browser: true, onevar: true, undef: true, nomen: true, eqeqeq: true,
  plusplus: true, bitwise: true, regexp: true, newcap: true, immed: true */
/*global $, window, document, navigator, google, mwf */

/* mwForum - Web-based discussion forum | Copyright 1999-2014 Markus Wichitill */

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

mwf.initAgentCharts = function () {
	mwf.showAgentChart("ua", $("#uaPie").data("array"));
	mwf.showAgentChart("os", $("#osPie").data("array"));
};

mwf.showAgentChart = function(id, array) {
	var data = new google.visualization.arrayToDataTable(array, true),
		chart = new google.visualization.PieChart($("#" + id + "Pie")[0]);
	chart.draw(data, {
		width: 250, height: 200, is3D: true, backgroundColor: "transparent",
		legend: "none", pieSliceText: "label", pieSliceTextStyle: { color: "black" },
		chartArea: { left: 0, top: 0, width: "100%", height: "100%" }
	});
};

mwf.initCountryChart = function () {
	var array = $("#map").data("array"),
		data = new google.visualization.arrayToDataTable(array, true),
		chart = new google.visualization.GeoChart($("#map")[0]);
	chart.draw(data, { backgroundColor: "transparent", legend: "none" });
};
