// Openstrator for Windows — native M1 editor UI
// Copyright (c) Openstrator contributors. No macOS/Adobe UI assets or code copied.
// Windows 10/11, Win32 + Direct2D + DirectWrite, C++20.
#define UNICODE
#define _UNICODE
#define NOMINMAX
#include <windows.h>
#include <windowsx.h>
#include <commdlg.h>
#include <d2d1.h>
#include <dwrite.h>
#include <wrl/client.h>
#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <memory>
#include <sstream>
#include <string>
#include "Core.hpp"
#pragma comment(lib, "d2d1.lib")
#pragma comment(lib, "dwrite.lib")
#pragma comment(lib, "comdlg32.lib")

using Microsoft::WRL::ComPtr;
using namespace osw;

namespace {
std::wstring wide(const std::string& s) {
    if (s.empty()) return {};
    int n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, s.data(), (int)s.size(), nullptr, 0);
    if (n <= 0) return L"[invalid UTF-8]";
    std::wstring v(n, L'\0');
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, s.data(), (int)s.size(), v.data(), n);
    return v;
}
std::string utf8(const std::wstring& s) {
    if (s.empty()) return {};
    int n = WideCharToMultiByte(CP_UTF8, 0, s.data(), (int)s.size(), nullptr, 0, nullptr, nullptr);
    std::string v(n, '\0'); WideCharToMultiByte(CP_UTF8, 0, s.data(), (int)s.size(), v.data(), n, nullptr, nullptr);
    return v;
}
D2D1_COLOR_F color(double r, double g, double b, double a = 1) {
    return D2D1::ColorF((FLOAT)std::clamp(r, 0., 1.), (FLOAT)std::clamp(g, 0., 1.),
        (FLOAT)std::clamp(b, 0., 1.), (FLOAT)std::clamp(a, 0., 1.));
}
D2D1_COLOR_F color(Color c, double opacity = 1) { return color(c.r,c.g,c.b,c.a*opacity); }
struct Rect { float left,top,right,bottom; bool contains(float x,float y) const {return x>=left&&x<right&&y>=top&&y<bottom;} };
D2D1_RECT_F drect(Rect r) { return D2D1::RectF(r.left,r.top,r.right,r.bottom); }
enum class Tool { Select, Rectangle, Ellipse, Line, Pen, Text, Hand };
const wchar_t* toolName(Tool t) {
    switch(t) {
        case Tool::Select:return L"Select";
        case Tool::Rectangle:return L"Rectangle";
        case Tool::Ellipse:return L"Ellipse";
        case Tool::Line:return L"Line";
        case Tool::Pen:return L"Pen";
        case Tool::Text:return L"Text";
        case Tool::Hand:return L"Hand";
    }
    return L"";
}
constexpr int SIDEBAR = 74;
constexpr int INSPECTOR = 310;
constexpr int HEADER = 96;
constexpr int FOOTER = 32;
constexpr int TEXT_EDIT_ID = 1301;
constexpr float PI = 3.14159265358979f;
}

class Application {
    HWND hwnd = nullptr, editBox = nullptr;
    ComPtr<ID2D1Factory> factory;
    ComPtr<ID2D1HwndRenderTarget> target;
    ComPtr<IDWriteFactory> writing;
    Editor editor;
    Tool tool = Tool::Select;
    int selected = -1, editing = -1;
    std::filesystem::path filePath;
    std::wstring status = L"Ready";
    float winW = 1360, winH = 840;
    double zoom = .72, panX = 0, panY = 0;
    bool dirty = false, dragging = false, didCheckpoint = false, panning = false;
    Point start{}, previous{}, current{};
    Point panStart{};
    std::vector<Point> penPoints;
    const Color accents[7] = {{.59,.43,.95,1},{.95,.36,.46,1},{.2,.64,.91,1},
        {.22,.74,.59,1},{.98,.72,.31,1},{.14,.18,.27,1},{1,1,1,1}};

    Rect viewport() const { return {(float)SIDEBAR,(float)HEADER,winW-INSPECTOR,winH-FOOTER}; }
    Point origin() const {
        Rect v = viewport();
        return {(v.left+v.right-editor.doc.width*zoom)/2 + panX,
                (v.top+v.bottom-editor.doc.height*zoom)/2 + panY};
    }
    Point toScreen(Point p) const { Point o=origin(); return {o.x+p.x*zoom,o.y+p.y*zoom}; }
    Point toDoc(float px,float py) const { Point o=origin(); return {(px-o.x)/zoom,(py-o.y)/zoom}; }
    bool inside(float x,float y) const { return viewport().contains(x,y); }
    D2D1_RECT_F pixelRect(float x,float y,float w,float h) { return D2D1::RectF(x,y,x+w,y+h); }
    void invalidate() { InvalidateRect(hwnd,nullptr,FALSE); }
    void note(const std::wstring& message) { status=message; invalidate(); }
    ComPtr<ID2D1SolidColorBrush> brush(D2D1_COLOR_F c) {
        ComPtr<ID2D1SolidColorBrush> b;
        if(target) target->CreateSolidColorBrush(c,&b);
        return b;
    }
    void box(Rect r,D2D1_COLOR_F c,float radius=0) {
        auto b=brush(c); if (!b) return;
        if(radius) target->FillRoundedRectangle(D2D1::RoundedRect(drect(r),radius,radius),b.Get());
        else target->FillRectangle(drect(r),b.Get());
    }
    void border(Rect r,D2D1_COLOR_F c,float stroke=1,float radius=0) {
        auto b=brush(c); if (!b) return;
        if(radius) target->DrawRoundedRectangle(D2D1::RoundedRect(drect(r),radius,radius),b.Get(),stroke);
        else target->DrawRectangle(drect(r),b.Get(),stroke);
    }
    void line(Point a,Point b,D2D1_COLOR_F c,float sw=1) {
        auto brush0=brush(c);
        if(brush0) target->DrawLine(D2D1::Point2F((float)a.x,(float)a.y),
            D2D1::Point2F((float)b.x,(float)b.y),brush0.Get(),sw);
    }
    void label(float x,float y,const std::wstring& s,float size,D2D1_COLOR_F c,DWRITE_FONT_WEIGHT weight=DWRITE_FONT_WEIGHT_NORMAL) {
        if(!writing || !target) return;
        ComPtr<IDWriteTextFormat> fmt;
        HRESULT hr=writing->CreateTextFormat(L"Segoe UI",nullptr,weight,DWRITE_FONT_STYLE_NORMAL,
            DWRITE_FONT_STRETCH_NORMAL,size,L"en-us",&fmt);
        if(FAILED(hr)) return;
        fmt->SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP);
        auto br=brush(c);
        if(br) target->DrawTextW(s.c_str(),(UINT32)s.size(),fmt.Get(),
            D2D1::RectF(x,y,x+std::max(1.f,winW-x),y+size*1.9f),br.Get());
    }
    void drawPath(const Shape& s) {
        std::vector<Anchor> a = s.anchors;
        if(a.empty()) for(const Point& p:s.points) { Anchor z;z.p=p;a.push_back(z); }
        if(a.empty()) return;
        ComPtr<ID2D1PathGeometry> path; if(FAILED(factory->CreatePathGeometry(&path))) return;
        ComPtr<ID2D1GeometrySink> sink; if(FAILED(path->Open(&sink))) return;
        Point start=toScreen(a.front().p);
        sink->BeginFigure(D2D1::Point2F((float)start.x,(float)start.y),
            s.closed ? D2D1_FIGURE_BEGIN_FILLED : D2D1_FIGURE_BEGIN_HOLLOW);
        for(size_t i=1;i<a.size();++i) {
            const Anchor &p=a[i-1],&q=a[i];
            if(p.hasOut||q.hasIn) {
                Point b=toScreen(p.hasOut?p.out:p.p),c=toScreen(q.hasIn?q.in:q.p),e=toScreen(q.p);
                sink->AddBezier(D2D1::BezierSegment(D2D1::Point2F((float)b.x,(float)b.y),
                    D2D1::Point2F((float)c.x,(float)c.y),D2D1::Point2F((float)e.x,(float)e.y)));
            } else {
                Point e=toScreen(q.p);sink->AddLine(D2D1::Point2F((float)e.x,(float)e.y));
            }
        }
        sink->EndFigure(s.closed ? D2D1_FIGURE_END_CLOSED : D2D1_FIGURE_END_OPEN);
        if(FAILED(sink->Close()))return;
        if(s.closed && s.fill.a>0) {auto fill=brush(color(s.fill,s.opacity));if(fill)target->FillGeometry(path.Get(),fill.Get());}
        if(s.stroke.a>0 && s.strokeWidth>0) {auto stroke=brush(color(s.stroke,s.opacity));if(stroke)target->DrawGeometry(path.Get(),stroke.Get(),(float)(s.strokeWidth*zoom));}
    }
    void drawShape(const Shape& s,bool active) {
        if(!s.visible) return;
        Point p=toScreen({s.x,s.y});
        float x=(float)p.x,y=(float)p.y,w=(float)(std::max(0.,s.w)*zoom),h=(float)(std::max(0.,s.h)*zoom);
        if(s.kind=="rectangle"||s.kind=="ellipse") {
            auto f=brush(color(s.fill,s.opacity)),st=brush(color(s.stroke,s.opacity));
            if(s.kind=="rectangle") {
                float rad=(float)(s.radius*zoom);
                if(f && s.fill.a>0) {
                    if(rad>0)target->FillRoundedRectangle(D2D1::RoundedRect(pixelRect(x,y,w,h),rad,rad),f.Get());
                    else target->FillRectangle(pixelRect(x,y,w,h),f.Get());
                }
                if(st && s.strokeWidth>0 && s.stroke.a>0) {
                    if(rad>0)target->DrawRoundedRectangle(D2D1::RoundedRect(pixelRect(x,y,w,h),rad,rad),st.Get(),(float)(s.strokeWidth*zoom));
                    else target->DrawRectangle(pixelRect(x,y,w,h),st.Get(),(float)(s.strokeWidth*zoom));
                }
            } else if(f && s.fill.a>0) target->FillEllipse(D2D1::Ellipse(D2D1::Point2F(x+w/2,y+h/2),w/2,h/2),f.Get());
            if(s.kind=="ellipse" && st && s.stroke.a>0 && s.strokeWidth>0)
                target->DrawEllipse(D2D1::Ellipse(D2D1::Point2F(x+w/2,y+h/2),w/2,h/2),st.Get(),(float)(s.strokeWidth*zoom));
        } else if(s.kind=="path"||s.kind=="line") drawPath(s);
        else if(s.kind=="text") label(x,y,wide(s.text),(float)(s.fontSize*zoom),color(s.fill,s.opacity),DWRITE_FONT_WEIGHT_SEMI_BOLD);
        else if(s.kind=="image") {
            box({x,y,x+w,y+h},color(.91,.93,.96),5);
            border({x,y,x+w,y+h},color(.65,.7,.78));
            label(x+14,y+14,L"Image (preview unavailable)",14,color(.35,.39,.49));
        } else {
            box({x,y,x+w,y+h},color(.83,.87,.94,.2),4);
            border({x,y,x+w,y+h},color(.55,.58,.71),1,4);
        }
        if(active) {
            Rect b{x-4,y-4,x+w+4,y+h+4};
            border(b,color(.54,.39,.97),1.5f);
            for(Point a:std::vector<Point>{{b.left,b.top},{b.right,b.top},{b.left,b.bottom},{b.right,b.bottom}}) {
                box({(float)a.x-3.5f,(float)a.y-3.5f,(float)a.x+3.5f,(float)a.y+3.5f},color(1,1,1));
                border({(float)a.x-3.5f,(float)a.y-3.5f,(float)a.x+3.5f,(float)a.y+3.5f},color(.54,.39,.97));
            }
        }
    }
    void paint() {
        PAINTSTRUCT ps;BeginPaint(hwnd,&ps);
        if(!target) createTarget();
        if(!target){EndPaint(hwnd,&ps);return;}
        target->BeginDraw();
        target->Clear(color(.087,.105,.15));
        // Header
        box({0,0,winW,HEADER},color(.12,.145,.197));
        box({0,0,winW,44},color(.105,.127,.176));
        box({19,9,45,35},color(.56,.41,.93),7);
        label(26,11,L"O",19,color(1,1,1),DWRITE_FONT_WEIGHT_BOLD);
        label(56,13,L"Openstrator",18,color(.96,.97,1),DWRITE_FONT_WEIGHT_BOLD);
        label(214,15,L"WINDOWS   /   MILESTONE 1",11,color(.62,.69,.81),DWRITE_FONT_WEIGHT_SEMI_BOLD);
        std::wstring title = wide(editor.doc.name)+(dirty?L"  •":L"");
        label(510,14,title,14,color(.78,.85,.96),DWRITE_FONT_WEIGHT_SEMI_BOLD);
        struct Action {const wchar_t* text;float x,w;};
        Action actions[]={{L"New",16,75},{L"Open",100,80},{L"Save",190,80},{L"Export SVG",280,125}};
        for(auto& a:actions){
            box({a.x,51,a.x+a.w,85},color(.18,.22,.30),7);
            border({a.x,51,a.x+a.w,85},color(.28,.33,.42),1,7);
            label(a.x+14,59,a.text,13,color(.88,.92,.98),DWRITE_FONT_WEIGHT_SEMI_BOLD);
        }
        label(winW-INSPECTOR-250,60,L"Ctrl+Z Undo     Ctrl+S Save",12,color(.62,.70,.81));
        // Left tool strip
        box({0,(float)HEADER,(float)SIDEBAR,winH-FOOTER},color(.13,.16,.22));
        const Tool all[]={Tool::Select,Tool::Rectangle,Tool::Ellipse,Tool::Line,Tool::Pen,Tool::Text,Tool::Hand};
        const wchar_t* key[]={L"V",L"R",L"E",L"L",L"P",L"T",L"H"};
        for(int n=0;n<7;n++){
            float y=HEADER+22.f+n*67;
            if(tool==all[n]) box({11,y,63,y+55},color(.33,.28,.49),9);
            label(28,y+7,key[n],19,tool==all[n]?color(.91,.83,1):color(.63,.72,.83),DWRITE_FONT_WEIGHT_BOLD);
            label(12,y+33,toolName(all[n]),10,color(.60,.67,.8));
        }
        // Main viewport and artboard
        Rect v=viewport();
        box(v,color(.195,.225,.286));
        target->PushAxisAlignedClip(drect(v),D2D1_ANTIALIAS_MODE_PER_PRIMITIVE);
        Point o=origin();Rect page{(float)o.x,(float)o.y,(float)(o.x+editor.doc.width*zoom),(float)(o.y+editor.doc.height*zoom)};
        box({page.left+9,page.top+13,page.right+9,page.bottom+13},color(.06,.07,.11,.25),4);
        box(page,color(1,1,1),1);
        border(page,color(.7,.72,.79),1);
        if(editor.doc.showGrid && editor.doc.grid*zoom>=9) {
            const double spacing=editor.doc.grid*zoom;
            for(double x=page.left+spacing;x<page.right;x+=spacing) line({x,page.top},{x,page.bottom},color(.87,.89,.93,.52));
            for(double y=page.top+spacing;y<page.bottom;y+=spacing) line({page.left,y},{page.right,y},color(.87,.89,.93,.52));
        }
        for(size_t n=0;n<editor.doc.shapes.size();++n)drawShape(editor.doc.shapes[n],(int)n==selected);
        if(dragging && tool!=Tool::Select && tool!=Tool::Hand && tool!=Tool::Text && tool!=Tool::Pen) {
            Shape preview=Shape::make(tool==Tool::Rectangle?"rectangle":tool==Tool::Ellipse?"ellipse":"line",
                {std::min(start.x,current.x),std::min(start.y,current.y)});
            preview.w=std::abs(current.x-start.x);preview.h=std::abs(current.y-start.y);
            if(tool==Tool::Line) { preview.points={start,current}; preview.anchors={{start},{current}}; }
            preview.opacity=.47;drawShape(preview,false);
        }
        if(penPoints.size()) {
            auto violet=color(.62,.43,.99);
            for(size_t i=1;i<penPoints.size();++i)line(toScreen(penPoints[i-1]),toScreen(penPoints[i]),violet,2.5f);
            for(auto& p:penPoints) {Point z=toScreen(p);box({(float)z.x-3,(float)z.y-3,(float)z.x+3,(float)z.y+3},color(1,1,1));border({(float)z.x-3,(float)z.y-3,(float)z.x+3,(float)z.y+3},violet);}
        }
        target->PopAxisAlignedClip();
        // Inspector
        float right=winW-INSPECTOR;
        box({right,(float)HEADER,winW,winH-FOOTER},color(.125,.151,.205));
        label(right+21,114,L"INSPECTOR",12,color(.72,.79,.9),DWRITE_FONT_WEIGHT_BOLD);
        box({right+16,145,winW-16,179},color(.18,.22,.29),7);
        label(right+26,155,L"Properties      Appearance      Layers",12,color(.87,.90,.98),DWRITE_FONT_WEIGHT_SEMI_BOLD);
        if(selected>=0 && selected<(int)editor.doc.shapes.size()) {
            const Shape& s=editor.doc.shapes[selected];
            label(right+20,203,wide(s.name),19,color(.95,.97,1),DWRITE_FONT_WEIGHT_SEMI_BOLD);
            label(right+20,239,wide(s.kind),12,color(.61,.7,.82));
            label(right+20,288,L"TRANSFORM",11,color(.65,.74,.86),DWRITE_FONT_WEIGHT_BOLD);
            auto field=[&](float x,float y,const wchar_t* k,double val) {
                box({x,y,x+129,y+40},color(.19,.23,.31),6);
                std::wostringstream ss;ss << k << L"    " << (int)std::lround(val);
                label(x+11,y+9,ss.str(),13,color(.88,.92,.98));
            };
            field(right+20,308,L"X",s.x);field(right+163,308,L"Y",s.y);
            field(right+20,356,L"W",s.w);field(right+163,356,L"H",s.h);
            label(right+20,426,L"FILL COLOR",11,color(.65,.74,.86),DWRITE_FONT_WEIGHT_BOLD);
            for(int n=0;n<7;n++) {
                float x=right+20+n*38.f;
                box({x,447,x+29,476},color(accents[n]),7);
                border({x,447,x+29,476},color(.75,.78,.85),1,7);
            }
            label(right+20,506,L"Opacity   "+std::to_wstring((int)(s.opacity*100))+L"%",13,color(.88,.92,.98));
        } else {
            label(right+20,208,L"No selection",15,color(.77,.83,.93));
            label(right+20,240,L"Click an object to inspect it.",12,color(.58,.68,.81));
        }
        label(right+20,552,L"LAYERS",11,color(.66,.75,.86),DWRITE_FONT_WEIGHT_BOLD);
        for(int row=0;row<5;row++){
            int n=(int)editor.doc.shapes.size()-1-row;
            if(n<0)break;
            float y=570.f+row*39.f;
            if(y>winH-FOOTER-26)break;
            if(n==selected) box({right+16,y-1,winW-16,y+34},color(.31,.28,.48),6);
            label(right+22,y+5,L"◈  "+wide(editor.doc.shapes[n].name),13,
                n==selected?color(1,1,1):color(.72,.79,.87));
        }
        // Footer/status
        box({0,winH-FOOTER,winW,winH},color(.10,.12,.17));
        label(17,winH-FOOTER+7,status,12,color(.67,.76,.87));
        std::wostringstream z;z << L"Zoom " << (int)std::lround(zoom*100) << L"%  •  "
          << editor.doc.shapes.size() << L" objects  •  " << toolName(tool);
        label(winW-INSPECTOR-270,winH-FOOTER+7,z.str(),12,color(.66,.73,.83));
        HRESULT hr=target->EndDraw();
        if(hr==D2DERR_RECREATE_TARGET) target.Reset();
        EndPaint(hwnd,&ps);
    }
    void createTarget() {
        if(!factory)return;
        RECT rc;GetClientRect(hwnd,&rc);
        D2D1_RENDER_TARGET_PROPERTIES props=D2D1::RenderTargetProperties();
        D2D1_HWND_RENDER_TARGET_PROPERTIES winprops=D2D1::HwndRenderTargetProperties(hwnd,
            D2D1::SizeU(std::max(1L,rc.right),std::max(1L,rc.bottom)));
        factory->CreateHwndRenderTarget(props,winprops,&target);
        if(target){target->SetAntialiasMode(D2D1_ANTIALIAS_MODE_PER_PRIMITIVE);target->SetTextAntialiasMode(D2D1_TEXT_ANTIALIAS_MODE_CLEARTYPE);}
    }
    Point snapPoint(Point p) const {
        if(!editor.doc.snap) return p;
        double g=editor.doc.grid;
        return {std::round(p.x/g)*g,std::round(p.y/g)*g};
    }
    int hit(Point p) const {
        for(int i=(int)editor.doc.shapes.size()-1;i>=0;--i) {
            const Shape& s=editor.doc.shapes[i];
            if(!s.visible || s.locked)continue;
            const double pad=7/zoom;
            if(p.x>=s.x-pad&&p.x<=s.x+s.w+pad&&p.y>=s.y-pad&&p.y<=s.y+s.h+pad)
                return i;
        }
        return -1;
    }
    void selectTool(Tool t) { tool=t;penPoints.clear();note(std::wstring(toolName(tool))+L" tool"); }
    void onDown(float x,float y) {
        if(y>51 && y<86) {
            if(x>=16&&x<91)newDoc();
            else if(x>=100&&x<180)open();
            else if(x>=190&&x<270)save();
            else if(x>=280&&x<405)exportSvg();
            return;
        }
        if(x<SIDEBAR && y>=HEADER+22) {
            int index=(int)((y-(HEADER+22))/67);
            if(index>=0 && index<7) selectTool((Tool)index);
            return;
        }
        float right=winW-INSPECTOR;
        if(x>=right) {
            if(selected>=0 && y>=447 && y<478) {
                int n=(int)((x-(right+20))/38);
                if(n>=0 && n<7) {
                    editor.checkpoint();editor.doc.shapes[selected].fill=accents[n];
                    dirty=true;note(L"Fill changed");return;
                }
            }
            if(y>=570 && selected<(int)editor.doc.shapes.size()) {
                int row=(int)((y-570)/39);
                int index=(int)editor.doc.shapes.size()-1-row;
                if(index>=0&&index<(int)editor.doc.shapes.size()) {
                    selected=index;note(L"Layer selected");return;
                }
            }
            return;
        }
        if(!inside(x,y))return;
        start=previous=current=snapPoint(toDoc(x,y));didCheckpoint=false;
        if(tool==Tool::Pen) {
            penPoints.push_back(start);
            note(L"Pen: click to add anchors; double-click to finish; Esc to cancel");
            return;
        }
        if(tool==Tool::Text) {
            editor.checkpoint();Shape s=Shape::make("text",start);
            editor.doc.shapes.push_back(s);
            selected=(int)editor.doc.shapes.size()-1;dirty=true;
            beginTextEdit(selected);return;
        }
        if(tool==Tool::Select) {
            selected=hit(start);
            if(selected>=0) {dragging=true;SetCapture(hwnd);note(L"Selected "+wide(editor.doc.shapes[selected].name));}
            else note(L"No selection");
            return;
        }
        dragging=true;panning=tool==Tool::Hand;
        panStart={panX,panY};
        SetCapture(hwnd);invalidate();
    }
    void onMove(float x,float y) {
        if(!dragging) return;
        current=snapPoint(toDoc(x,y));
        if(panning) {
            panX=panStart.x+(x-(float)toScreen(start).x);
            panY=panStart.y+(y-(float)toScreen(start).y);
        } else if(tool==Tool::Select && selected>=0) {
            double dx=current.x-previous.x,dy=current.y-previous.y;
            if((std::abs(dx)>1e-7||std::abs(dy)>1e-7) && !editor.doc.shapes[selected].locked) {
                if(!didCheckpoint){editor.checkpoint();didCheckpoint=true;}
                editor.doc.shapes[selected].translate(dx,dy);dirty=true;
            }
            previous=current;
        }
        invalidate();
    }
    void onUp(float x,float y) {
        if(!dragging)return;
        if(GetCapture()==hwnd)ReleaseCapture();
        current=snapPoint(toDoc(x,y));
        dragging=false;
        if(panning){panning=false;note(L"Canvas panned");return;}
        if(tool==Tool::Select){if(didCheckpoint)note(L"Object moved");return;}
        double left=std::min(start.x,current.x),top=std::min(start.y,current.y);
        double width=std::abs(start.x-current.x),height=std::abs(start.y-current.y);
        if(std::max(width,height)<4) {note(L"Drag to draw a shape");return;}
        editor.checkpoint();
        Shape s=Shape::make(tool==Tool::Rectangle?"rectangle":tool==Tool::Ellipse?"ellipse":"line",{left,top});
        s.w=std::max(1.,width);s.h=std::max(1.,height);
        if(tool==Tool::Line) {
            s.points={start,current};
            Anchor a,b;a.p=start;b.p=current;s.anchors={a,b};
        }
        editor.doc.shapes.push_back(std::move(s));
        selected=(int)editor.doc.shapes.size()-1;
        dirty=true;note(L"Shape created");invalidate();
    }
    void finishPen() {
        if(penPoints.size()>=2) {
            editor.checkpoint();Shape s=Shape::make("path",penPoints.front());
            double minx=penPoints.front().x,maxx=minx,miny=penPoints.front().y,maxy=miny;
            for(auto& p:penPoints){
                minx=std::min(minx,p.x);maxx=std::max(maxx,p.x);
                miny=std::min(miny,p.y);maxy=std::max(maxy,p.y);
                Anchor a;a.p=p;s.anchors.push_back(a);s.points.push_back(p);
            }
            s.x=minx;s.y=miny;s.w=std::max(1.,maxx-minx);s.h=std::max(1.,maxy-miny);
            editor.doc.shapes.push_back(std::move(s));
            selected=(int)editor.doc.shapes.size()-1;dirty=true;
            note(L"Path created");
        }
        penPoints.clear();invalidate();
    }
    void beginTextEdit(int index) {
        if(index<0||index>=(int)editor.doc.shapes.size()||editor.doc.shapes[index].kind!="text")return;
        if(editBox){SetFocus(editBox);return;}
        editing=index;
        Shape& s=editor.doc.shapes[index];Point p=toScreen({s.x,s.y});
        editBox=CreateWindowExW(WS_EX_CLIENTEDGE,L"EDIT",wide(s.text).c_str(),
            WS_CHILD|WS_VISIBLE|WS_BORDER|ES_AUTOHSCROLL,
            (int)p.x,(int)p.y,std::max(160,(int)(s.w*zoom)),36,hwnd,(HMENU)(INT_PTR)TEXT_EDIT_ID,
            GetModuleHandleW(nullptr),nullptr);
        if(editBox){SendMessageW(editBox,WM_SETFONT,(WPARAM)GetStockObject(DEFAULT_GUI_FONT),TRUE);SetFocus(editBox);SendMessageW(editBox,EM_SETSEL,0,-1);}
    }
    void commitText() {
        if(!editBox)return;
        HWND field=editBox;editBox=nullptr;
        int n=GetWindowTextLengthW(field);
        std::wstring text((size_t)n+1,L'\0');
        GetWindowTextW(field,text.data(),n+1);text.resize(n);
        DestroyWindow(field);
        if(editing>=0&&editing<(int)editor.doc.shapes.size()&&editor.doc.shapes[editing].text!=utf8(text)) {
            editor.checkpoint();editor.doc.shapes[editing].text=utf8(text);
            dirty=true;note(L"Text edited");
        }
        editing=-1;
    }
    bool confirmClose() {
        if(!dirty)return true;
        int result=MessageBoxW(hwnd,L"Your current document has unsaved changes.\nClose without saving?",L"Openstrator",MB_YESNO|MB_ICONWARNING|MB_DEFBUTTON2);
        return result==IDYES;
    }
    std::filesystem::path dialog(bool saveAs,bool svgFile=false) {
        wchar_t buf[32768]={0};
        OPENFILENAMEW f{};f.lStructSize=sizeof(f);f.hwndOwner=hwnd;
        static const wchar_t filterDoc[]=L"Openstrator documents (*.openstrator)\0*.openstrator\0All files\0*.*\0\0";
        static const wchar_t filterSvg[]=L"SVG vector images (*.svg)\0*.svg\0\0";
        f.lpstrFilter=svgFile?filterSvg:filterDoc;f.lpstrFile=buf;f.nMaxFile=32768;
        f.lpstrDefExt=svgFile?L"svg":L"openstrator";
        f.Flags=OFN_PATHMUSTEXIST|(saveAs?OFN_OVERWRITEPROMPT:OFN_FILEMUSTEXIST);
        bool ok=saveAs?GetSaveFileNameW(&f):GetOpenFileNameW(&f);
        return ok?std::filesystem::path(buf):std::filesystem::path();
    }
    void write(const std::filesystem::path& path,const std::string& bytes) {
        std::filesystem::path temp=path;temp+=L".tmp";
        {
            std::ofstream stream(temp,std::ios::binary|std::ios::trunc);
            if(!stream)throw std::runtime_error("Cannot write file");
            stream.write(bytes.data(),(std::streamsize)bytes.size());
            stream.close();
            if(!stream)throw std::runtime_error("Write was interrupted");
        }
        // Windows ReplaceFile requires a pre-existing destination.
        if(std::filesystem::exists(path)) {
            if(!ReplaceFileW(path.c_str(),temp.c_str(),nullptr,REPLACEFILE_IGNORE_MERGE_ERRORS,nullptr,nullptr))
                throw std::runtime_error("Could not replace destination file");
        } else if(!MoveFileExW(temp.c_str(),path.c_str(),MOVEFILE_WRITE_THROUGH))
            throw std::runtime_error("Could not finalize saved file");
    }
    void save(bool saveAs=false) {
        commitText();
        if(filePath.empty()||saveAs) {
            std::filesystem::path p=dialog(true);
            if(p.empty())return;
            filePath=p;
        }
        try {
            editor.doc.name=utf8(filePath.stem().wstring());
            write(filePath,editor.doc.save());
            dirty=false;note(L"Saved "+filePath.filename().wstring());
        }catch(const std::exception& e){MessageBoxW(hwnd,wide(e.what()).c_str(),L"Save failed",MB_ICONERROR);}
    }
    void open() {
        commitText();if(!confirmClose())return;
        auto path=dialog(false);if(path.empty())return;
        try {
            std::ifstream f(path,std::ios::binary);if(!f)throw std::runtime_error("Cannot read document");
            f.seekg(0,std::ios::end);auto size=f.tellg();
            if(size<0||size>64*1024*1024)throw std::runtime_error("Document exceeds 64 MiB safety limit");
            f.seekg(0);std::string bytes((std::istreambuf_iterator<char>(f)),{});
            Document parsed=Document::load(bytes);
            editor.doc=std::move(parsed);
            editor.undoHistory.clear();editor.redoHistory.clear();
            selected=-1;penPoints.clear();panX=panY=0;dirty=false;
            filePath=editor.doc.importedAdvanced?std::filesystem::path():path;
            note(L"Opened "+path.filename().wstring());
            if(editor.doc.importedAdvanced)
                MessageBoxW(hwnd,L"This macOS document contains advanced M6 data.\n\n"
                    L"Openstrator Windows M1 renders only basic vector shapes and text. "
                    L"Unknown JSON fields are preserved, but effects, fonts, masks and images "
                    L"are NOT fully rendered. Saving requires a new copy to protect the original. "
                    L"SVG export is basic and excludes image/effect fidelity.",L"Compatibility preview",MB_ICONINFORMATION);
        }catch(const std::exception& e){MessageBoxW(hwnd,wide(e.what()).c_str(),L"Open failed",MB_ICONERROR);}
        invalidate();
    }
    void newDoc() {
        commitText();if(!confirmClose())return;
        editor=Editor{};filePath.clear();selected=-1;zoom=.72;panX=panY=0;dirty=false;penPoints.clear();
        note(L"New 1200 x 800 document");invalidate();
    }
    void exportSvg() {
        commitText();auto path=dialog(true,true);if(path.empty())return;
        try {
            write(path,svg(editor.doc));
            if(editor.doc.importedAdvanced) note(L"SVG exported (advanced effects/images not included)");
            else note(L"SVG exported: "+path.filename().wstring());
        }catch(const std::exception& e){MessageBoxW(hwnd,wide(e.what()).c_str(),L"SVG export failed",MB_ICONERROR);}
    }
    void key(WPARAM code) {
        bool ctrl=(GetKeyState(VK_CONTROL)&0x8000)!=0,shift=(GetKeyState(VK_SHIFT)&0x8000)!=0;
        if(ctrl){
            if(code=='N')newDoc();
            if(code=='O')open();
            if(code=='S')save(shift);
            if(code=='E')exportSvg();
            if(code=='Z'){commitText();if(editor.undo()){dirty=true;selected=-1;note(L"Undo");}}
            if(code=='Y'){commitText();if(editor.redo()){dirty=true;selected=-1;note(L"Redo");}}
            if(code=='G'){editor.doc.showGrid=!editor.doc.showGrid;note(L"Grid visibility toggled");}
            if(code==VK_OEM_PLUS||code==VK_ADD){zoom=std::min(4.,zoom*1.2);invalidate();}
            if(code==VK_OEM_MINUS||code==VK_SUBTRACT){zoom=std::max(.1,zoom/1.2);invalidate();}
            return;
        }
        if(code==VK_F1){
            MessageBoxW(hwnd,L"Tools: V Select, R Rectangle, E Ellipse, L Line, P Pen, T Text, H Hand\n"
                L"Double-click a text object to edit.\nDouble-click or Enter to finish a Pen path.\n"
                L"File: Ctrl+N New, Ctrl+O Open, Ctrl+S Save, Ctrl+Shift+S Save As, Ctrl+E Export SVG\n"
                L"Edit: Ctrl+Z Undo, Ctrl+Y Redo, Delete removes selection\n"
                L"View: Mouse wheel zoom, Ctrl+G grid visibility, Ctrl++ / Ctrl+- zoom.\n"
                L"Openstrator Windows M1 does not yet render advanced M6 features.",L"Openstrator Windows shortcuts",MB_OK);return;
        }
        if(code==VK_ESCAPE){penPoints.clear();selected=-1;invalidate();return;}
        if(code==VK_RETURN && tool==Tool::Pen){finishPen();return;}
        if(code==VK_DELETE&&selected>=0&&selected<(int)editor.doc.shapes.size()){
            editor.checkpoint();editor.doc.shapes.erase(editor.doc.shapes.begin()+selected);
            selected=-1;dirty=true;note(L"Object deleted");return;
        }
        if(code=='V')selectTool(Tool::Select);
        else if(code=='R')selectTool(Tool::Rectangle);
        else if(code=='E')selectTool(Tool::Ellipse);
        else if(code=='L')selectTool(Tool::Line);
        else if(code=='P')selectTool(Tool::Pen);
        else if(code=='T')selectTool(Tool::Text);
        else if(code=='H')selectTool(Tool::Hand);
        else if(code==VK_F2 && selected>=0)beginTextEdit(selected);
    }

public:
    bool initialize(HINSTANCE hInst,int show) {
        SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
        if(FAILED(D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED,&factory)))return false;
        if(FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED,__uuidof(IDWriteFactory),reinterpret_cast<IUnknown**>(writing.GetAddressOf()))))return false;
        WNDCLASSEXW wc{};wc.cbSize=sizeof(wc);wc.style=CS_HREDRAW|CS_VREDRAW|CS_DBLCLKS;
        wc.lpfnWndProc=[](HWND h,UINT m,WPARAM w,LPARAM l)->LRESULT{
            auto self=reinterpret_cast<Application*>(GetWindowLongPtrW(h,GWLP_USERDATA));
            if(m==WM_NCCREATE) {
                auto cs=reinterpret_cast<CREATESTRUCTW*>(l);
                self=reinterpret_cast<Application*>(cs->lpCreateParams);
                SetWindowLongPtrW(h,GWLP_USERDATA,reinterpret_cast<LONG_PTR>(self));
                self->hwnd=h;
            }
            return self?self->dispatch(m,w,l):DefWindowProcW(h,m,w,l);
        };
        wc.hInstance=hInst;wc.hCursor=LoadCursorW(nullptr,IDC_ARROW);
        wc.hIcon=LoadIconW(nullptr,IDI_APPLICATION);
        wc.hbrBackground=(HBRUSH)GetStockObject(BLACK_BRUSH);wc.lpszClassName=L"OpenstratorWindowM1";
        if(!RegisterClassExW(&wc))return false;
        hwnd=CreateWindowExW(0,wc.lpszClassName,L"Openstrator — Windows M1",WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT,CW_USEDEFAULT,1360,860,nullptr,nullptr,hInst,this);
        if(!hwnd)return false;
        ShowWindow(hwnd,show);UpdateWindow(hwnd);return true;
    }
    int run() {
        MSG m{};while(GetMessageW(&m,nullptr,0,0)>0){TranslateMessage(&m);DispatchMessageW(&m);}
        return (int)m.wParam;
    }
    LRESULT dispatch(UINT m,WPARAM w,LPARAM l) {
        switch(m) {
        case WM_SIZE: {
            winW=(float)LOWORD(l);winH=(float)HIWORD(l);
            if(target && winW>0&&winH>0)target->Resize(D2D1::SizeU((UINT32)winW,(UINT32)winH));
            invalidate();return 0;
        }
        case WM_DPICHANGED: {
            auto r=reinterpret_cast<RECT*>(l);
            SetWindowPos(hwnd,nullptr,r->left,r->top,r->right-r->left,r->bottom-r->top,SWP_NOZORDER|SWP_NOACTIVATE);
            return 0;
        }
        case WM_ERASEBKGND:return 1;
        case WM_PAINT:paint();return 0;
        case WM_LBUTTONDOWN:onDown((float)GET_X_LPARAM(l),(float)GET_Y_LPARAM(l));return 0;
        case WM_MOUSEMOVE:onMove((float)GET_X_LPARAM(l),(float)GET_Y_LPARAM(l));return 0;
        case WM_LBUTTONUP:onUp((float)GET_X_LPARAM(l),(float)GET_Y_LPARAM(l));return 0;
        case WM_LBUTTONDBLCLK:
            if(tool==Tool::Pen){finishPen();return 0;}
            if(tool==Tool::Select){
                Point p=toDoc((float)GET_X_LPARAM(l),(float)GET_Y_LPARAM(l));
                int i=hit(p);if(i>=0&&editor.doc.shapes[i].kind=="text"){selected=i;beginTextEdit(i);}
            }return 0;
        case WM_MOUSEWHEEL: {
            RECT r;GetClientRect(hwnd,&r);
            zoom=std::clamp(zoom*(GET_WHEEL_DELTA_WPARAM(w)>0?1.12:.89),.08,6.);
            invalidate();return 0;
        }
        case WM_COMMAND:
            if(LOWORD(w)==TEXT_EDIT_ID&&HIWORD(w)==EN_KILLFOCUS){commitText();return 0;}
            break;
        case WM_KEYDOWN:
            if(editBox && GetFocus()==editBox)break;
            key(w);return 0;
        case WM_CLOSE:if(confirmClose())DestroyWindow(hwnd);return 0;
        case WM_DESTROY:PostQuitMessage(0);return 0;
        }
        return DefWindowProcW(hwnd,m,w,l);
    }
};
int WINAPI wWinMain(HINSTANCE hInst,HINSTANCE,LPWSTR,int show) {
    if(FAILED(CoInitializeEx(nullptr,COINIT_APARTMENTTHREADED)))return 1;
    Application app;
    if(!app.initialize(hInst,show)){MessageBoxW(nullptr,L"Unable to initialize Openstrator.",L"Openstrator",MB_ICONERROR);CoUninitialize();return 1;}
    int result=app.run();CoUninitialize();return result;
}
