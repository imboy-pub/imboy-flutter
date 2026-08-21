//
//  ShareViewController.swift
//  ShareExtension
//
//  E2EE 备份导入：继承 share_handler_ios 提供的基类，不写自定义逻辑。
//  基类负责把共享文件复制到 App Group 容器并通过 URL scheme 跳回主 App。
//

import UIKit
import share_handler_ios_models

@available(iOSApplicationExtension 14.0, *)
class ShareViewController: ShareHandlerIosViewController {
    // 无需覆写任何方法；基类已处理文件/图片/视频/文本/URL/数据
}
