import XCTest
@testable import CodeJump

final class ShellExecutorTests: XCTestCase {
    func testLocalArgumentsExpandTilde() {
        let project = RemoteProject(host: RemoteProject.localHostTag, remotePath: "~/Project", editorId: Editor.builtinVSCode.id, isLocal: true)
        XCTAssertEqual(ShellExecutor.arguments(for: project), [NSString(string: "~/Project").expandingTildeInPath])
    }

    func testRemoteArgumentsUseFolderURI() {
        let project = RemoteProject(host: "server", remotePath: "/work/project", editorId: Editor.builtinVSCode.id)
        XCTAssertEqual(ShellExecutor.arguments(for: project), ["--folder-uri", "vscode-remote://ssh-remote+server/work/project"])
    }
}
