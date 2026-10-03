# 樊老师网课播放器（原生 UWP）

Windows 10 原生 UWP 网课播放器。

## 当前开发顺序

1. MP4：H.264 / H.265 / HEVC
2. 播放列表
3. 收藏文件夹
4. SMB 局域网文件
5. 高级深色播放界面
6. 色温调节
7. 智能反色
8. 百分比裁切、移动、缩放、恢复
9. 头像遮罩
10. 全屏与窗口缩放保持定位
11. Windows 10 展台模式
12. 后续再接天翼云盘 / 百度网盘

## 原插件基准

`MosuanTianyiKiosk/Web/MosuanPlayer.js` 为转向 UWP 前的 Edge 插件 V1.0 核心存档，UWP 的反色、裁切、遮罩行为以该版本为功能基准。

## 核心原则

- 原生 UWP，不依赖 Edge 插件
- 第一阶段不使用 VLC
- 播放内核优先使用 Windows MediaPlayer / Media Foundation
- 云盘作为后续 Provider，不影响播放器核心
