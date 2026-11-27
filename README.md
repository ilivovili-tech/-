# 相册 · XiangCe

一款以年度照片书为核心的原生 iOS 相册整理应用。独立 SwiftUI 项目，不依赖原有的 WeChatStyleDemo。

## 当前版本

- 年度照片书封面与轻量 3D 视觉效果，支持左右滑动与按钮切换月份
- 原生 Apple Live Photo 实况照片播放（按住照片播放）
- 视频详情页内播放
- 读取系统照片图库，按时间浏览照片和视频
- 展示系统相簿
- 在应用内创建系统照片相簿
- 打开相簿查看其中照片
- 从照片详情页将照片添加到指定相簿
- 按拍摄时间相近、视频、连拍三类筛选图库内容
- 支持多选并在二次确认后批量移至系统“最近删除”
- 年度照片书中的缩略图可直接打开照片详情
- 统计照片与视频数量，并监听系统照片图库变化
- 往年今日回忆
- 照片/视频数量统计
- 删除前确认，并交由 iOS 照片图库管理
- GitHub Actions 自动构建未签名 IPA

## 构建

项目使用 XcodeGen：

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project XiangCe.xcodeproj -scheme XiangCe -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions 会在推送到 `main` 后构建，并在 Actions 运行记录中提供 `相册-iOS-IPA` 工件；也可以在 Actions 页面手动运行 iOS Build。

## 隐私与权限

照片通过 Apple Photos / PhotoKit 在设备本地读取。首次使用时由系统弹窗请求照片访问权限。应用不会把照片上传到服务器。

删除操作需要用户确认，并由系统照片图库处理；“最近删除”的恢复和永久删除仍由 iOS 系统照片 App 管理。

## 后续计划

- 更细腻的 3D 翻页动效与年度照片书封面自定义
- 月份/日期时间轴
- 用户自定义相簿、封面和标题
- 更完善的相似照片与连拍辅助分组
- 月度回忆卡片、主题设置和完善的空状态
