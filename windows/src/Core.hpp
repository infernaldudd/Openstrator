#pragma once
// Openstrator Windows M1 — original portable C++ document/vector core.
// Compatible with the common OpenDocument/VectorObject JSON keys in macOS V6 M6.
// Unknown JSON properties are retained during native document saves.
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <deque>
#include <iomanip>
#include <map>
#include <random>
#include <sstream>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace osw {
struct Json {
    enum class Type { Null, Bool, Number, String, Array, Object };
    Type type = Type::Null;
    bool boolean = false;
    double number = 0;
    std::string text;
    std::vector<Json> array;
    std::map<std::string, Json> object;
    Json() = default;
    Json(std::nullptr_t) {}
    Json(bool v) : type(Type::Bool), boolean(v) {}
    Json(int v) : type(Type::Number), number(v) {}
    Json(double v) : type(Type::Number), number(v) {}
    Json(const char* v) : type(Type::String), text(v) {}
    Json(std::string v) : type(Type::String), text(std::move(v)) {}
    static Json arr() { Json v; v.type = Type::Array; return v; }
    static Json obj() { Json v; v.type = Type::Object; return v; }
    const Json& at(const std::string& key) const {
        auto it = object.find(key);
        static const Json none;
        return type == Type::Object && it != object.end() ? it->second : none;
    }
    Json& operator[](const std::string& key) {
        if (type != Type::Object) { *this = obj(); }
        return object[key];
    }
    bool contains(const std::string& k) const {
        return type == Type::Object && object.count(k) != 0;
    }
    double num(double fallback = 0) const {
        return type == Type::Number && std::isfinite(number) ? number : fallback;
    }
    std::string str(const std::string& fallback = "") const {
        return type == Type::String ? text : fallback;
    }
    bool yes(bool fallback = false) const { return type == Type::Bool ? boolean : fallback; }
    static void appendUtf8(std::string& out, uint32_t c) {
        if (c <= 0x7F) out.push_back(char(c));
        else if (c <= 0x7FF) { out.push_back(char(0xC0 | (c >> 6))); out.push_back(char(0x80 | (c & 63))); }
        else if (c <= 0xFFFF) { out.push_back(char(0xE0 | (c >> 12))); out.push_back(char(0x80 | ((c >> 6) & 63))); out.push_back(char(0x80 | (c & 63))); }
        else { out.push_back(char(0xF0 | (c >> 18))); out.push_back(char(0x80 | ((c >> 12) & 63))); out.push_back(char(0x80 | ((c >> 6) & 63))); out.push_back(char(0x80 | (c & 63))); }
    }
    class Parser {
        const std::string& s;
        size_t i = 0;
        void whitespace() { while (i < s.size() && (s[i] == ' ' || s[i] == '\r' || s[i] == '\n' || s[i] == '\t')) ++i; }
        bool accept(char c) { whitespace(); if (i < s.size() && s[i] == c) { ++i; return true; } return false; }
        void expect(char c) { if (!accept(c)) throw std::runtime_error("Invalid JSON syntax"); }
        uint32_t hex4() {
            if (i + 4 > s.size()) throw std::runtime_error("Truncated Unicode escape");
            uint32_t v = 0;
            for (int k = 0; k < 4; ++k) {
                char c = s[i++]; v <<= 4;
                if (c >= '0' && c <= '9') v |= c - '0';
                else if (c >= 'a' && c <= 'f') v |= 10 + c - 'a';
                else if (c >= 'A' && c <= 'F') v |= 10 + c - 'A';
                else throw std::runtime_error("Invalid Unicode escape");
            }
            return v;
        }
        std::string string() {
            whitespace();
            if (i >= s.size() || s[i++] != '"') throw std::runtime_error("Expected JSON string");
            std::string out;
            while (i < s.size()) {
                unsigned char c = (unsigned char)s[i++];
                if (c == '"') return out;
                if (c < 32) throw std::runtime_error("Unescaped control character");
                if (c != '\\') { out.push_back(char(c)); continue; }
                if (i >= s.size()) throw std::runtime_error("Truncated JSON escape");
                char e = s[i++];
                switch (e) {
                case '"': case '\\': case '/': out.push_back(e); break;
                case 'b': out.push_back('\b'); break;
                case 'f': out.push_back('\f'); break;
                case 'n': out.push_back('\n'); break;
                case 'r': out.push_back('\r'); break;
                case 't': out.push_back('\t'); break;
                case 'u': {
                    uint32_t cp = hex4();
                    if (cp >= 0xD800 && cp <= 0xDBFF) {
                        if (i + 2 > s.size() || s[i++] != '\\' || s[i++] != 'u')
                            throw std::runtime_error("Missing low surrogate");
                        uint32_t low = hex4();
                        if (low < 0xDC00 || low > 0xDFFF) throw std::runtime_error("Invalid low surrogate");
                        cp = 0x10000 + ((cp - 0xD800) << 10) + low - 0xDC00;
                    } else if (cp >= 0xDC00 && cp <= 0xDFFF) throw std::runtime_error("Unexpected low surrogate");
                    appendUtf8(out, cp); break;
                }
                default: throw std::runtime_error("Invalid JSON escape");
                }
            }
            throw std::runtime_error("Unterminated JSON string");
        }
        Json value(int depth) {
            if (depth > 120) throw std::runtime_error("JSON too deeply nested");
            whitespace();
            if (i >= s.size()) throw std::runtime_error("Truncated JSON");
            if (s[i] == '"') return Json(string());
            if (accept('{')) {
                Json v = Json::obj();
                if (accept('}')) return v;
                do { std::string k = string(); expect(':'); v.object[k] = value(depth + 1); if (accept('}')) return v; expect(','); } while (true);
            }
            if (accept('[')) {
                Json v = Json::arr();
                if (accept(']')) return v;
                do { v.array.push_back(value(depth + 1)); if (accept(']')) return v; expect(','); } while (true);
            }
            if (s.compare(i, 4, "true") == 0) { i += 4; return Json(true); }
            if (s.compare(i, 5, "false") == 0) { i += 5; return Json(false); }
            if (s.compare(i, 4, "null") == 0) { i += 4; return Json(); }
            if (s[i] == '-' || (s[i] >= '0' && s[i] <= '9')) {
                size_t start = i;
                if (s[i] == '-') ++i;
                if (i >= s.size()) throw std::runtime_error("Bad JSON number");
                if (s[i] == '0') ++i;
                else { if (s[i] < '1' || s[i] > '9') throw std::runtime_error("Bad JSON number");
                    while (i < s.size() && s[i] >= '0' && s[i] <= '9') ++i; }
                if (i < s.size() && s[i] == '.') { ++i; if (i >= s.size() || s[i] < '0' || s[i] > '9') throw std::runtime_error("Bad decimal"); while (i < s.size() && s[i] >= '0' && s[i] <= '9') ++i; }
                if (i < s.size() && (s[i] == 'e' || s[i] == 'E')) { ++i; if (i < s.size() && (s[i] == '+' || s[i] == '-')) ++i; if (i >= s.size() || s[i] < '0' || s[i] > '9') throw std::runtime_error("Bad exponent"); while (i < s.size() && s[i] >= '0' && s[i] <= '9') ++i; }
                double x = std::strtod(s.c_str() + start, nullptr);
                if (!std::isfinite(x)) throw std::runtime_error("Non-finite JSON number");
                return Json(x);
            }
            throw std::runtime_error("Unexpected JSON token");
        }
    public:
        explicit Parser(const std::string& input) : s(input) {}
        Json parse() { Json v = value(0); whitespace(); if (i != s.size()) throw std::runtime_error("Unexpected trailing JSON"); return v; }
    };
    static Json parse(const std::string& input) { return Parser(input).parse(); }
    static std::string quote(const std::string& s) {
        std::string out = "\"";
        static const char* h = "0123456789abcdef";
        for (unsigned char c : s) {
            switch (c) {
            case '"': out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\n': out += "\\n"; break;
            case '\r': out += "\\r"; break;
            case '\t': out += "\\t"; break;
            default:
                if (c < 32) { out += "\\u00"; out += h[c >> 4]; out += h[c & 15]; }
                else out.push_back(char(c));
            }
        }
        return out + "\"";
    }
    std::string dump(int depth = 0) const {
        if (depth > 120) throw std::runtime_error("JSON nesting too deep");
        switch (type) {
        case Type::Null: return "null";
        case Type::Bool: return boolean ? "true" : "false";
        case Type::String: return quote(text);
        case Type::Number: { std::ostringstream o; o << std::setprecision(17) << number; return o.str(); }
        case Type::Array: {
            if (array.empty()) return "[]";
            std::string out = "[\n";
            for (size_t n = 0; n < array.size(); ++n) { out += std::string((depth + 1) * 2, ' ') + array[n].dump(depth + 1) + (n + 1 == array.size() ? "\n" : ",\n"); }
            return out + std::string(depth * 2, ' ') + "]";
        }
        case Type::Object: {
            if (object.empty()) return "{}";
            std::string out = "{\n";
            size_t n = 0;
            for (auto& [k, v] : object) { out += std::string((depth + 1) * 2, ' ') + quote(k) + ": " + v.dump(depth + 1) + (++n == object.size() ? "\n" : ",\n"); }
            return out + std::string(depth * 2, ' ') + "}";
        }
        }
        return "";
    }
};
struct Point { double x = 0, y = 0; };
struct Color { double r = 0.15, g = 0.49, b = 0.98, a = 1; };
inline Point readPoint(const Json& v) { return {v.at("x").num(), v.at("y").num()}; }
inline Json pointJson(Point p) { Json v = Json::obj(); v["x"] = p.x; v["y"] = p.y; return v; }
inline Color readColor(const Json& v, Color fallback) {
    if (v.type != Json::Type::Object) return fallback;
    return {v.at("r").num(fallback.r), v.at("g").num(fallback.g), v.at("b").num(fallback.b), v.at("a").num(fallback.a)};
}
inline Json colorJson(Color c) {
    Json v = Json::obj(); v["r"] = c.r; v["g"] = c.g; v["b"] = c.b; v["a"] = c.a; return v;
}
inline std::string uuid() {
    static std::mt19937_64 rng{std::random_device{}()};
    char b[37] {};
    auto a = rng(), c = rng();
    std::snprintf(b, sizeof(b), "%08llx-%04llx-4%03llx-%04llx-%012llx",
        (unsigned long long)(a >> 32), (unsigned long long)((a >> 16) & 0xffff),
        (unsigned long long)(a & 0xfff), (unsigned long long)((c & 0x3fff) | 0x8000),
        (unsigned long long)(c >> 16));
    return b;
}
struct Anchor { Point p, in, out; bool hasIn = false, hasOut = false; std::string kind = "corner"; Json raw = Json::obj(); };
struct Shape {
    Json raw = Json::obj();
    std::string id, name = "Shape", kind = "rectangle", text = "Text";
    double x = 0, y = 0, w = 160, h = 110, radius = 0;
    double opacity = 1, rotation = 0, strokeWidth = 0, fontSize = 42;
    Color fill, stroke{0.1, 0.1, 0.12, 0};
    bool visible = true, locked = false, closed = false;
    std::vector<Point> points;
    std::vector<Anchor> anchors;
    static Shape from(const Json& v) {
        Shape s; s.raw = v;
        s.id = v.at("id").str(); s.name = v.at("name").str("Shape");
        s.kind = v.at("kind").str("rectangle"); s.text = v.at("text").str("Text");
        s.x = v.at("x").num(); s.y = v.at("y").num();
        s.w = v.at("width").num(160); s.h = v.at("height").num(110);
        s.radius = v.at("cornerRadius").num(); s.opacity = v.at("opacity").num(1);
        s.rotation = v.at("rotation").num(); s.strokeWidth = v.at("strokeWidth").num();
        s.fontSize = v.at("fontSize").num(42);
        s.fill = readColor(v.at("fill"), {1,1,1,1});
        s.stroke = readColor(v.at("stroke"), {0.1,0.1,0.12,1});
        s.visible = v.at("isVisible").yes(true); s.locked = v.at("isLocked").yes(false);
        s.closed = v.at("isClosed").yes();
        for (auto& p : v.at("points").array) s.points.push_back(readPoint(p));
        for (auto& a : v.at("bezierAnchors").array) {
            Anchor z; z.raw = a; z.kind = a.at("kind").str("corner"); z.p = readPoint(a.at("point"));
            z.hasIn = a.at("inHandle").type == Json::Type::Object;
            z.hasOut = a.at("outHandle").type == Json::Type::Object;
            if (z.hasIn) z.in = readPoint(a.at("inHandle"));
            if (z.hasOut) z.out = readPoint(a.at("outHandle"));
            s.anchors.push_back(z);
        }
        return s;
    }
    static Shape make(std::string k, Point at) {
        Shape s; s.id = uuid(); s.kind = std::move(k); s.name = s.kind;
        s.x = at.x; s.y = at.y;
        if (s.kind == "ellipse") s.fill = {0.92, 0.36, 0.48, 1};
        if (s.kind == "line" || s.kind == "path") { s.fill.a = 0; s.stroke = {0.15,0.19,0.27,1}; s.strokeWidth = 2; }
        if (s.kind == "text") { s.text = "Type something"; s.fill = {0.11, 0.13, 0.18, 1}; s.w = 300; s.h = 70; }
        return s;
    }
    void translate(double dx, double dy) {
        x += dx; y += dy;
        for (auto& p : points) { p.x += dx; p.y += dy; }
        for (auto& a : anchors) {
            a.p.x += dx; a.p.y += dy;
            if (a.hasIn) { a.in.x += dx; a.in.y += dy; }
            if (a.hasOut) { a.out.x += dx; a.out.y += dy; }
        }
    }
    Json toJson() const {
        Json v = raw.type == Json::Type::Object ? raw : Json::obj();
        v["id"] = id; v["name"] = name; v["kind"] = kind;
        v["x"] = x; v["y"] = y; v["width"] = w; v["height"] = h;
        v["rotation"] = rotation; v["opacity"] = opacity; v["fill"] = colorJson(fill);
        v["stroke"] = colorJson(stroke); v["strokeWidth"] = strokeWidth;
        v["cornerRadius"] = radius; v["text"] = text; v["fontSize"] = fontSize;
        v["isVisible"] = visible; v["isLocked"] = locked;
        if (!v.contains("blendMode")) v["blendMode"] = "normal";
        if (!v.contains("fontWeight")) v["fontWeight"] = 0.4;
        if (!v.contains("effects")) v["effects"] = Json::arr();
        if (!v.contains("points")) v["points"] = Json::arr();
        if (kind == "path" || kind == "line" || raw.contains("points")) {
            Json a = Json::arr();
            for (auto& p : points) a.array.push_back(pointJson(p));
            v["points"] = a;
        }
        if ((kind == "path" || kind == "line") && (!anchors.empty() || raw.contains("bezierAnchors"))) {
            Json a = Json::arr();
            for (auto& z : anchors) {
                Json t = z.raw.type == Json::Type::Object ? z.raw : Json::obj();
                t["point"] = pointJson(z.p); t["kind"] = z.kind;
                if (z.hasIn) t["inHandle"] = pointJson(z.in);
                if (z.hasOut) t["outHandle"] = pointJson(z.out);
                a.array.push_back(t);
            }
            v["bezierAnchors"] = a;
        }
        if (kind == "path" || kind == "line") v["isClosed"] = closed;
        return v;
    }
};
struct Document {
    Json original = Json::obj();
    std::string name = "Untitled";
    double width = 1200, height = 800, grid = 24;
    bool showGrid = true, snap = false, importedAdvanced = false;
    std::vector<Shape> shapes;
    static Document blank() {
        Document d; d.original["formatVersion"] = 2; d.original["name"] = "Untitled";
        d.original["background"] = colorJson({1,1,1,1}); d.original["guides"] = Json::arr();
        d.original["showGuides"] = true; d.original["showGrid"] = true;
        d.original["snapToGrid"] = false; d.original["gridSpacing"] = 24;
        d.original["objects"] = Json::arr();
        return d;
    }
    static Document load(const std::string& bytes) {
        Document d; d.original = Json::parse(bytes);
        if (d.original.type != Json::Type::Object ||
            d.original.at("objects").type != Json::Type::Array)
            throw std::runtime_error("Not a valid .openstrator document (missing objects array)");
        d.name = d.original.at("name").str("Untitled");
        d.width = d.original.at("artboardWidth").num(1200);
        d.height = d.original.at("artboardHeight").num(800);
        if (d.width < 1 || d.height < 1 || d.width > 200000 || d.height > 200000)
            throw std::runtime_error("Invalid artboard dimensions");
        d.grid = std::max(2., d.original.at("gridSpacing").num(24));
        d.showGrid = d.original.at("showGrid").yes(true);
        d.snap = d.original.at("snapToGrid").yes(false);
        d.importedAdvanced = d.original.contains("layerTree") || d.original.contains("resourceLibrary") || d.original.contains("rasterAssets");
        for (auto& v : d.original.at("objects").array) {
            if (v.type != Json::Type::Object) throw std::runtime_error("Invalid vector object");
            Shape s = Shape::from(v);
            if (s.kind == "image" || s.raw.contains("typography") || s.raw.contains("appearanceStack")
                || s.raw.contains("clippingGroupID") || s.raw.contains("layerNodeID"))
                d.importedAdvanced = true;
            d.shapes.push_back(std::move(s));
        }
        return d;
    }
    std::string save() const {
        Json root = original; root["formatVersion"] = root.at("formatVersion").type == Json::Type::Number ? root.at("formatVersion") : Json(2);
        root["name"] = name; root["artboardWidth"] = width; root["artboardHeight"] = height;
        root["gridSpacing"] = grid; root["showGrid"] = showGrid; root["snapToGrid"] = snap;
        if (!root.contains("showGuides")) root["showGuides"] = true;
        if (!root.contains("guides")) root["guides"] = Json::arr();
        if (!root.contains("background")) root["background"] = colorJson({1,1,1,1});
        Json arr = Json::arr();
        for (auto& shape : shapes) arr.array.push_back(shape.toJson());
        root["objects"] = std::move(arr);
        return root.dump() + "\n";
    }
};
struct Editor {
    Document doc = Document::blank();
    std::deque<Document> undoHistory, redoHistory;
    void checkpoint() {
        undoHistory.push_back(doc);
        if (undoHistory.size() > 64) undoHistory.pop_front();
        redoHistory.clear();
    }
    bool undo() {
        if (undoHistory.empty()) return false;
        redoHistory.push_back(doc); doc = undoHistory.back(); undoHistory.pop_back(); return true;
    }
    bool redo() {
        if (redoHistory.empty()) return false;
        undoHistory.push_back(doc); doc = redoHistory.back(); redoHistory.pop_back(); return true;
    }
};
inline std::string xmlEscape(const std::string& s) {
    std::string out;
    for (char c : s) {
        if (c == '&') out += "&amp;";
        else if (c == '<') out += "&lt;";
        else if (c == '>') out += "&gt;";
        else if (c == '"') out += "&quot;";
        else if (c == '\'') out += "&apos;";
        else out.push_back(c);
    }
    return out;
}
inline std::string rgb(Color c) {
    auto channel=[](double x){ return int(std::round(std::clamp(x, 0., 1.) * 255)); };
    char b[9]; std::snprintf(b, sizeof(b), "#%02x%02x%02x", channel(c.r), channel(c.g), channel(c.b));
    return b;
}
inline std::string svg(const Document& d) {
    std::ostringstream o; o << std::setprecision(12);
    o << "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    o << "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"" << d.width << "\" height=\"" << d.height
      << "\" viewBox=\"0 0 " << d.width << " " << d.height << "\">\n";
    for (auto& s : d.shapes) {
        if (!s.visible || s.kind == "image") continue; // unsupported image embedding: no false fidelity claim
        std::string fill = s.fill.a <= 0 ? "none" : rgb(s.fill);
        std::string stroke = s.stroke.a <= 0 || s.strokeWidth <= 0 ? "none" : rgb(s.stroke);
        o << "  <g opacity=\"" << std::clamp(s.opacity, 0., 1.) << "\"";
        if (s.rotation) o << " transform=\"rotate(" << s.rotation << " " << s.x+s.w/2 << " " << s.y+s.h/2 << ")\"";
        o << ">\n";
        o << "    ";
        if (s.kind == "rectangle") {
            o << "<rect x=\"" << s.x << "\" y=\"" << s.y << "\" width=\"" << s.w << "\" height=\"" << s.h << "\" rx=\"" << s.radius << "\"";
        } else if (s.kind == "ellipse") {
            o << "<ellipse cx=\"" << s.x+s.w/2 << "\" cy=\"" << s.y+s.h/2 << "\" rx=\"" << s.w/2 << "\" ry=\"" << s.h/2 << "\"";
        } else if (s.kind == "text") {
            o << "<text x=\"" << s.x << "\" y=\"" << s.y+s.fontSize << "\" font-size=\"" << s.fontSize
              << "\" fill=\"" << fill << "\">" << xmlEscape(s.text) << "</text>\n  </g>\n"; continue;
        } else if (s.kind == "line" || s.kind == "path") {
            o << "<path d=\"";
            if (!s.anchors.empty()) {
                o << "M " << s.anchors.front().p.x << " " << s.anchors.front().p.y << " ";
                for (size_t i = 1; i < s.anchors.size(); ++i) {
                    const auto& a = s.anchors[i-1]; const auto& b = s.anchors[i];
                    if (a.hasOut || b.hasIn) {
                        Point p1 = a.hasOut ? a.out : a.p; Point p2 = b.hasIn ? b.in : b.p;
                        o << "C " << p1.x << " " << p1.y << " " << p2.x << " " << p2.y << " " << b.p.x << " " << b.p.y << " ";
                    } else o << "L " << b.p.x << " " << b.p.y << " ";
                }
            } else if (!s.points.empty()) {
                o << "M " << s.points.front().x << " " << s.points.front().y << " ";
                for (size_t i = 1; i < s.points.size(); ++i) o << "L " << s.points[i].x << " " << s.points[i].y << " ";
            }
            if (s.closed) o << "Z ";
            o << "\"";
        } else { o << "<!-- Unsupported kind " << xmlEscape(s.kind) << " -->\n  </g>\n"; continue; }
        o << " fill=\"" << fill << "\" fill-opacity=\"" << s.fill.a
          << "\" stroke=\"" << stroke << "\" stroke-opacity=\"" << s.stroke.a
          << "\" stroke-width=\"" << s.strokeWidth << "\" />\n  </g>\n";
    }
    o << "</svg>\n"; return o.str();
}
} // namespace osw
