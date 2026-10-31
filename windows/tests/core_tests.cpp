#ifdef NDEBUG
#undef NDEBUG // Release builds must execute assertions in the test executable.
#endif
#include "Core.hpp"
#include <cassert>
#include <cmath>
#include <iostream>
#include <stdexcept>
using namespace osw;
int main() {
    Json j=Json::parse(R"({"name":"Openstrator","test":[true,false,null,1.25],"unicode":"\uD83D\uDE80","backslash":"a\\b"})");
    assert(j.at("name").str()=="Openstrator");
    assert(j.at("test").array.size()==4 && j.at("test").array[1].yes(true)==false);
    assert(j.at("unicode").str()=="\xF0\x9F\x9A\x80");
    assert(Json::parse(j.dump()).dump()==j.dump());
    for(auto bad: {"{\"x\":2,}", "[1,]", "{\"x\":\"\\uD801\"}", "{", "1e999999", "\"\x01\""}) {
        bool failed=false;try{Json::parse(bad);}catch(const std::runtime_error&){failed=true;}assert(failed);
    }
    std::string mac=R"({
      "formatVersion":2, "name":"Mac M6", "artboardWidth":1200, "artboardHeight":800,
      "layerTree":{"id":"legacy-layer","children":[{"hidden":"kept"}]},
      "resourceLibrary":{"future":[1,2,3]},
      "rasterAssets":[{"id":"photo","embeddedData":"unchanged"}],
      "objects":[{
        "id":"00000000-0000-4000-8000-000000000001",
        "name":"Cubic", "kind":"path", "x":10,"y":20,"width":100,"height":100,
        "fill":{"r":0.1,"g":0.2,"b":0.3,"a":0},
        "stroke":{"r":0.2,"g":0.2,"b":0.2,"a":1},"strokeWidth":3,
        "appearanceStack":{"future":true},
        "bezierAnchors":[{"point":{"x":10,"y":20},"outHandle":{"x":50,"y":12},"kind":"smooth"},
                         {"point":{"x":110,"y":120},"inHandle":{"x":105,"y":95},"kind":"corner"}],
        "points":[{"x":10,"y":20},{"x":110,"y":120}],
        "isVisible":true, "isLocked":false
      }]
    })";
    Document d=Document::load(mac);
    assert(d.importedAdvanced && d.shapes.size()==1);
    assert(d.shapes.front().anchors.size()==2);
    assert(d.shapes.front().anchors[0].hasOut && d.shapes.front().anchors[1].hasIn);
    d.shapes.front().translate(5,7);
    Json saved=Json::parse(d.save());
    assert(saved.at("layerTree").at("children").array[0].at("hidden").str()=="kept");
    assert(saved.at("resourceLibrary").at("future").array.size()==3);
    assert(saved.at("rasterAssets").array[0].at("embeddedData").str()=="unchanged");
    assert(saved.at("objects").array[0].at("appearanceStack").at("future").yes());
    assert(saved.at("objects").array[0].at("bezierAnchors").array[0].at("point").at("x").num()==15);
    assert(saved.at("objects").array[0].at("bezierAnchors").array[0].at("kind").str()=="smooth");
    assert(Document::load(d.save()).shapes[0].y==27);
    auto path=svg(d);
    assert(path.find("C 55 19 110 102 115 127")!=std::string::npos);
    Document n=Document::blank();
    Shape s=Shape::make("text",{42,50});s.text="Openstrator & <Windows>";
    n.shapes.push_back(s);
    assert(svg(n).find("Openstrator &amp; &lt;Windows&gt;")!=std::string::npos);
    Editor ed;ed.checkpoint();ed.doc.shapes.push_back(s);
    assert(ed.doc.shapes.size()==1);assert(ed.undo());assert(ed.doc.shapes.empty());
    assert(ed.redo());assert(ed.doc.shapes.size()==1);
    std::cout << "Openstrator Windows core tests passed\n";
}
