# 0.2.2
* The cache size Android APP storageStats.  GetCacheBytes ();  APP cacheBytes for ios macos is defined as NSHomeDirectory() + "/Library/Caches" + NSHomeDirectory() + "/tmp"
* 其他一些细节调整

# 0.2.1
* 修复”删除我的收藏“返回上一页的问题；
* 修复”删除该设备“返回上一页的问题；
* 修复”设置设备名“完成按钮不高亮的问题；
* 修复 incomingCallScreen 的时候没有 initIceServers 的问题；
* 新增 MessageService.to.sendAckMsg/2 方法，调整相关逻辑；
* macos 权限配置调整

# 0.2.0
* 新增“存储空间”UI特效；
* 新增获取设备已用空间、设备可用空间、设置磁盘空间、应用缓存、应用用户数据功能（依赖 ic_storage_space 库，Android版本需要8.0及以上）
* 管理“聊天记录功能”(TODO)
* 升级一些依赖；
* 

# 0.1.28
* 修复“一对一语音视频”消息红点在取消、接受会话后，不-1的的问题；
* 移除会话消息“标记已读、标记未读”功能
* API 签名后缀调整 appVsnXY 修改为 appVsnMajor

# 0.1.27
* 升级 getx get: ^5.0.0-release-candidate-5 代码做响应调整，https://github.com/jonataslaw/getx/issues/2966；
* 修复升级到 getx 5 引发的调整相关问题；

# 0.1.26
* 引入 octo_image 库，聊天图片做相关调整；
* 引入 r_upgrade 库，做Android IOS APP升级功能；
* 其他一些细节调整，升级一些依赖；

# 0.1.25
* 引入 drag_ball，用户反馈新增 type rating 字段，调整提交用户反馈体验等；
* 升级voice_message_package: ^2.1.4 调整 CustomMessageBuilder width Get.widht * 0.85
* 修复 n.showDialog/3 点击取消无效的问题；
* 登录或者注册的时候，提交表单之前经过，密码一次md5加密，保证调试代码的打印日志的时候也不泄露用户密码；
* 引入 flutter_rating_bar，用户反馈评级使用五星评级;
* 添加回复列表；
* 使用 image: ^4.1.3 替换 flutter_image_compress: ^2.1.0 做图片压缩；
* 修复 conversation/lastTime 问题，取最近聊天消息的created_at；
* 用户反馈新增联系方式字段；
* 其他代码格式调整；
* 升级一些依赖

# 0.1.24
* 引入 feedback flutter_image_compress; 
* 去除置里面的“帮助反馈”选项；
* 设置页面新增“更新日志、帮助文档”两个页面；
* 新增提交“反馈建议”功能；
* 新增反馈建议列表；
* 新增“反馈建议明细”页面；
* 新增 zoomInPhotoViewGallery/1 方法，显示多个图像并让用户在它们之间进行更改的效果；
* 新增删除反馈建议；
* 升级一些依赖

# 0.1.23
* 修复文本消息过长导致的“RenderFlex overflowed”错误
* TextButton 取消圆角边框，设置 foregroundColor: AppColors.ItemOnColor
* 不压缩聊天消息中上传的图片；
* 收藏里面显示图片Size等信息；
* WebSocket 心跳间隔时间到到100S;
* 适配 Flutter 3.16；
* useMaterial3: true，调整相应代码；
* 收藏详情UI优化等；
* 升级一些依赖

# 0.1.22
* 新增设置收藏备注功能；
* 优化个人信息里面->修改昵称、更多信息->性别、更多信息->地区、更多信息->个性签名 操作用户体验；
* 升级一些依赖

# 0.1.21
* 个人信息显示登录邮箱；
* 可复制收藏的文本消息；
* 关闭网络的情况下，关闭WebSocket服务；
* ext.kotlin_version = '1.9.10'; dart run flutter_native_splash:create ;
* 升级一些依赖

# 0.1.20
* 优化二维码扫描体验，新增copy扫描结果等功能；
* 单聊发送"收藏"消息功能；
* 升级一些flutter三方依赖；

# 0.1.19
* 附件消息（图片、文件、语音消息、视频等）携带filemd5值；
* 我的收藏列表，样式小调整；
* EntityVideo.filesize 属性修改为 EntityVideo.size；
* 升级一些flutter三方依赖，一些dart代码语法调整；

# 0.1.18
* 解决 refreshAccessToken 过期后，登录页面被重复刷新的问题; 
* 更新若干依赖；

# 0.1.17
* 修复刷新token验证签名不通过的问题；
* 更新一些依赖；

# 0.1.16
* 修复 peerTitle 为空的问题、修复收到消息会话 title 为空的问题；
* 修复下拉刷新联系人列表，联系人排序跳动的问题; 
* 修复循环refreshToken问题；
* 升级flutter 到 stable, 3.13.0 , 设置 ext.kotlin_version = '1.8.20' , 升级其他几个依赖; dart run flutter_native_splash:create

# 0.1.15
* P2P会话  peer 参数类型从 UserModel 修改为 ContactModel；
* 更新会话的时候重新计算会话消息提醒数量；
* 修正音视频通话接收端没有接听消息，也在会话列表中写入"已取消"消息；
* 其他变量命名风格等一些细节调整（sqlite DDL语句有变化，需要卸载APP重新安装）；

# 0.1.14
* 添加 WebRTCMessageBuilder ，实现"语音通话"、"视频通话"消息记录；
* 修复语音通话无法达到 WebRTCCallState.CallStateConnected 状态问题；
* 修复"新注册的朋友"列表，nickname 为空就显示 account ;
* 更新两个依赖；

# 0.1.13
* 修复"删除只有一条消息的会话里面的消息报错"的问题，并且如果删除是图片消息一并移除对应会话的 gallery
* 修复添加好友昵称、头像弄反的问题；
* 修复扫码添加好友 source 信息丢失问题；
* 关于IMBoy 后面显示版本号；
* 刷新token请求添加两个header参数（method sign）；
* Flutter中滑动出现_positions.isNotEmpty异常解决办法；

# 0.1.12
* 新增全局变量 appVsnXY 和 deviceId ，替换相关代码；
* 新增 EncrypterService.sha512/2 方法，修正 EncrypterService.sha256/2 方法；
* 调整 API sign 参数刷分，新增默认header method 制定签名算法
* http_client 的 get post delete 3 个方法新增 检查状态码为 705 的情况，遇到705，刷新token后重新请求一次； 

# 0.1.11
* 实现“服务端通知客户端刷新token”功能；
* 升级几个依赖包，其他一些语法调整

# 0.1.10
* 新增新注册的朋友列表
* 申请好友、确认好友实现添加标签功能
* 拉取“新注册的朋友”列表的时候更新本地“存在的联系人基本信息”
* 修正底部菜单定位问题
* 我的收藏第1页没有查到数据的时候到服务端去查询; 
* app 被唤醒的时候检查token是否过期
* 其他一些细节优化

# 0.1.9
* 修复文档消息长按效果右键菜单不显示问题
* 修复“部分 Get.defaultDialog() 效果用 n.Alert() 替换”
* 暂时用不上 fluent_ui，移除之；
* 添加 popover: ^0.2.8+2 ，应用到会话列表右上角弹出菜单;（之前基于 popup_menu实现）
* 添加 sensors_plus: ^3.0.2 # 用于访问加速度计、陀螺仪和磁力计传感器的 Flutter 插件。(暂时没使用)
* 升级几个依赖


# 0.1.8
* 我的收藏编辑标签功能
* 我的收藏显示标签、按单个标签查询功能

# 0.1.7
* ”联系人标签详情添加联系人“，成功后数据状态同步处理；
* 删除tag 清理本地数据；
* 联系人标签，默认加载本地记录
* 调整联系人"添加标签"页面样式，实现输入框换行功能


# 0.1.6
* 联系人标签-新建标签
* 联系人标签详情列表
* 从标签中移除联系人
* 联系人标签详情添加联系人

# 0.1.5
* 引入 dio_http2_adapter 2.3.0 ，代码做相应调整
* 实现“更改标签名称、删除标签”功能；

# 0.1.4
* 联系人标签分页列表
* 联系人标签搜索

# 0.1.3
* 联系人设置备注功能
* 联系人设置标签功能
* 我的收藏添加标签功能
* 添加 fluent_ui: ^4.4.0  textfield_tags: ^2.0.2 依赖


# 0.1.2
* 我的收藏相关功能


# 0.1.1
参考 feature_0.1.0_tree.md 文档里面的早期添加的功能
