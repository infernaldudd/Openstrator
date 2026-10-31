import XCTest
@testable import OpenstratorCore

final class SnapEngineTests: XCTestCase {
    func testVerticalGuideSnapsOnlyXWithinTolerance() throws {
        var d = DocumentV6.empty(width:500,height:400)
        try d.insert(DocumentNode(name:"Guide",payload:.guide(.init(axis:"vertical",position:100))),parent:d.rootID,index:d.rootChildren.count)
        let r = SnapEngine.snap(point:.init(x:96,y:73),document:d,options:.init(tolerance:5,grid:false,guides:true,anchors:false,artboards:false))
        XCTAssertEqual(r.point.x,100,accuracy:0.001)
        XCTAssertEqual(r.point.y,73,accuracy:0.001)
        XCTAssertEqual(r.candidates.first?.kind,.guide)
    }

    func testPathAnchorCanSnapBothAxes() throws {
        var d=DocumentV6.empty(width:500,height:400)
        var n=DocumentNode(name:"Path",payload:.path(.init(anchors:[.init(point:.init(x:40,y:50)),.init(point:.init(x:120,y:90))])))
        n.transform = .translation(x: 10, y: 20)
        try d.insert(n,parent:d.activeArtboardID,index:0)
        let r=SnapEngine.snap(point:.init(x:52,y:68),document:d,options:.init(tolerance:4,grid:false,guides:false,anchors:true,artboards:false))
        XCTAssertEqual(r.point.x,50,accuracy:0.001)
        XCTAssertEqual(r.point.y,70,accuracy:0.001)
        XCTAssertTrue(r.candidates.contains { $0.kind == .anchor })
    }

    func testArtboardEdgeAndCenterSnap() {
        let d=DocumentV6.empty(width:400,height:300)
        let edge=SnapEngine.snap(point:.init(x:397,y:80),document:d,options:.init(tolerance:5,grid:false,guides:false,anchors:false,artboards:true))
        XCTAssertEqual(edge.point.x,400,accuracy:0.001)
        let center=SnapEngine.snap(point:.init(x:202,y:148),document:d,options:.init(tolerance:4,grid:false,guides:false,anchors:false,artboards:true))
        XCTAssertEqual(center.point.x,200,accuracy:0.001)
        XCTAssertEqual(center.point.y,150,accuracy:0.001)
    }

    func testNearestCandidateWinsPerAxis() throws {
        var d=DocumentV6.empty(width:500,height:400)
        try d.insert(DocumentNode(name:"G1",payload:.guide(.init(axis:"vertical",position:100))),parent:d.rootID,index:d.rootChildren.count)
        try d.insert(DocumentNode(name:"G2",payload:.guide(.init(axis:"vertical",position:103))),parent:d.rootID,index:d.rootChildren.count)
        let r=SnapEngine.snap(point:.init(x:102.4,y:70),document:d,options:.init(tolerance:6,grid:false,guides:true,anchors:false,artboards:false))
        XCTAssertEqual(r.point.x,103,accuracy:0.001)
    }

    func testDisabledSourcesDoNotSnap() throws {
        var d=DocumentV6.empty(width:500,height:400)
        try d.insert(DocumentNode(name:"Guide",payload:.guide(.init(axis:"vertical",position:100))),parent:d.rootID,index:d.rootChildren.count)
        let p=CGPoint(x:98,y:77)
        let r=SnapEngine.snap(point:p,document:d,options:.init(tolerance:10,grid:false,guides:false,anchors:false,artboards:false))
        XCTAssertEqual(r.point,p)
        XCTAssertTrue(r.candidates.isEmpty)
    }
}
