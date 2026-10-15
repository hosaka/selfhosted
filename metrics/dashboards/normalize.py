"""Normalize Grafana dashboard JSON: shared key order, and drop values that equal
Grafana 13.1 defaults or have no effect. Defaults were taken from the v13.1.1
panel option builders (timeseries/config.ts, stat, piechart, logs, table modules,
grafana-ui legend/tooltip/axis/hideSeries builders).

Usage, e.g. after editing a dashboard or exporting one from Grafana:

    python3 normalize.py < caddy-monitor.json > /tmp/out.json && mv /tmp/out.json caddy-monitor.json

Panel types without an entry in the defaults below (heatmap, dashlist, state-timeline, ...)
only get the generic cleanup, so their options are kept as they are."""
import json
import sys

DASHBOARD_ORDER = ["uid", "title", "description", "tags", "editable", "graphTooltip", "refresh",
                   "schemaVersion", "time", "timepicker", "timezone", "templating", "annotations",
                   "links", "panels"]
DASHBOARD_DROP = {"id": None, "gnetId": "*", "style": "*", "version": "*", "liveNow": False,
                  "fiscalYearStartMonth": 0, "weekStart": "", "refresh": [False, ""], "graphTooltip": 0,
                  "timezone": "", "tags": [], "links": []}

PANEL_ORDER = ["id", "type", "title", "description", "datasource", "gridPos", "repeat", "collapsed",
               "transparent", "interval", "targets", "transformations", "fieldConfig", "options", "panels"]
PANEL_DROP = {"pluginVersion": "*", "links": [], "description": "", "transparent": False, "datasource": None}

TARGET_ORDER = ["refId", "datasource", "expr", "format", "instant", "range", "exemplar", "step",
                "interval", "legendFormat", "queryType", "hide"]
TARGET_DROP = {"editorMode": "*", "interval": "", "hide": False, "format": "time_series", "intervalFactor": 1}

VARIABLE_ORDER = ["name", "label", "description", "type", "datasource", "query", "definition", "refresh",
                  "sort", "multi", "includeAll", "allValue", "current", "hide"]
VARIABLE_DROP = {"hide": 0, "options": [], "regex": "", "skipUrlSync": False, "tagValuesQuery": "",
                 "tagsQuery": "", "useTags": False, "current": {}, "includeAll": False, "multi": False,
                 "allValue": ""}

FIELD_ORDER = ["unit", "decimals", "min", "max", "noValue", "color", "thresholds", "mappings", "links", "custom"]

HIDE_FROM = {"legend": False, "tooltip": False, "viz": False}
CUSTOM_DEFAULTS = {
    "timeseries": {
        "drawStyle": "line", "lineInterpolation": "linear", "lineWidth": 1, "fillOpacity": 0,
        "gradientMode": "none", "barAlignment": 0, "barWidthFactor": 0.6,
        "stacking": {"mode": "none", "group": "A"}, "axisCenteredZero": False, "axisBorderShow": False,
        "axisColorMode": "text", "axisLabel": "", "axisPlacement": "auto",
        "scaleDistribution": {"type": "linear"}, "hideFrom": HIDE_FROM, "showPoints": "auto",
        "pointSize": 5, "spanNulls": False, "insertNulls": False, "showValues": False,
        "thresholdsStyle": {"mode": "off"},
    },
    "piechart": {"hideFrom": HIDE_FROM},
    "table": {"align": "auto", "cellOptions": {"type": "auto"}, "inspect": False},
}
COLOR_DEFAULTS = {"timeseries": {"mode": "palette-classic"}, "piechart": {"mode": "palette-classic"}}

LEGEND_DEFAULTS = {"displayMode": "list", "placement": "bottom", "showLegend": True, "calcs": []}
TOOLTIP_DEFAULTS = {"mode": "single", "sort": "none"}
REDUCE_DEFAULTS = {"calcs": ["lastNotNull"], "fields": "", "values": False}
OPTION_DEFAULTS = {
    "stat": {"colorMode": "value", "graphMode": "area", "justifyMode": "auto", "textMode": "auto",
             "wideLayout": True, "showPercentChange": False, "orientation": "auto", "text": {}},
    "piechart": {"pieType": "pie", "displayLabels": []},
    "logs": {"showTime": False, "showLabels": False, "showCommonLabels": False, "wrapLogMessage": False,
             "enableLogDetails": True, "dedupStrategy": "none", "sortOrder": "Descending"},
    "table": {"cellHeight": "sm", "showHeader": True, "frameIndex": 0, "showTypeIcons": False,
              "sortBy": [], "footer": {"show": False}},
}


def drop(obj, rules):
    for key, value in rules.items():
        if key not in obj:
            continue
        values = value if isinstance(value, list) and value and value[0] is False else [value]
        if value == "*" or obj[key] in values:
            del obj[key]


def ordered(obj, order):
    head = {k: obj[k] for k in order if k in obj}
    head.update({k: v for k, v in obj.items() if k not in head})
    return head


def prune(obj, defaults):
    for key, value in defaults.items():
        if obj.get(key) == value:
            del obj[key]


def thresholds_unused(panel, defaults):
    color_mode = defaults.get("color", {}).get("mode", "palette-classic")
    if color_mode == "thresholds" or "thresholds" in color_mode:
        return False
    if panel["type"] == "timeseries" and defaults.get("custom", {}).get("thresholdsStyle", {"mode": "off"})["mode"] != "off":
        return False
    for override in panel.get("fieldConfig", {}).get("overrides", []):
        for prop in override["properties"]:
            if prop["id"] in ("color", "custom.thresholdsStyle", "custom.cellOptions") and "thresholds" in json.dumps(prop["value"]):
                return False
    return panel["type"] in ("timeseries", "stat", "piechart")


def normalize_panel(panel):
    kind = panel["type"]
    drop(panel, PANEL_DROP)
    if kind == "row":
        if panel.get("collapsed") is False:
            del panel["collapsed"]
        panel.pop("datasource", None)
        if not panel.get("panels"):
            panel.pop("panels", None)

    for target in panel.get("targets", []):
        drop(target, TARGET_DROP)
        if target.get("instant") is False and "range" not in target:
            del target["instant"]
    if "targets" in panel:
        panel["targets"] = [ordered(t, TARGET_ORDER) for t in panel["targets"]]

    field_config = panel.get("fieldConfig")
    if field_config is not None:
        defaults = field_config.get("defaults", {})
        for key in ("mappings", "links"):
            if defaults.get(key) == []:
                del defaults[key]
        if "color" in defaults and defaults["color"] == COLOR_DEFAULTS.get(kind):
            del defaults["color"]
        custom = defaults.get("custom")
        if custom is not None:
            prune(custom, CUSTOM_DEFAULTS.get(kind, {}))
            if not custom:
                del defaults["custom"]
        if "thresholds" in defaults and thresholds_unused(panel, defaults):
            del defaults["thresholds"]
        field_config["defaults"] = ordered(defaults, FIELD_ORDER)
        if not field_config.get("overrides"):
            field_config.pop("overrides", None)
        if not field_config["defaults"] and "overrides" not in field_config:
            del panel["fieldConfig"]

    options = panel.get("options")
    if options is not None:
        prune(options, OPTION_DEFAULTS.get(kind, {}))
        for key, defaults in (("legend", LEGEND_DEFAULTS), ("tooltip", TOOLTIP_DEFAULTS), ("reduceOptions", REDUCE_DEFAULTS)):
            if key in options:
                prune(options[key], defaults)
                if kind == "piechart" and key == "legend":
                    options[key].pop("calcs", None)  # the pie chart legend has no calcs
                if not options[key]:
                    del options[key]
        if not options:
            del panel["options"]

    if "panels" in panel:
        panel["panels"] = [normalize_panel(p) for p in panel["panels"]]
    return ordered(panel, PANEL_ORDER)


def normalize(dashboard):
    drop(dashboard, DASHBOARD_DROP)
    annotations = dashboard.get("annotations", {}).get("list", [])
    # grafana adds the built-in "Annotations & Alerts" query itself when it's missing
    if all(a.get("builtIn") == 1 for a in annotations):
        dashboard.pop("annotations", None)
    variables = dashboard.get("templating", {}).get("list", [])
    for variable in variables:
        drop(variable, VARIABLE_DROP)
    if variables:
        dashboard["templating"]["list"] = [ordered(v, VARIABLE_ORDER) for v in variables]
    else:
        dashboard.pop("templating", None)
    dashboard["panels"] = [normalize_panel(p) for p in dashboard["panels"]]
    return ordered(dashboard, DASHBOARD_ORDER)


if __name__ == "__main__":
    json.dump(normalize(json.load(sys.stdin)), sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")
