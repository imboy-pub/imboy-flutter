#!/bin/bash
# ImBoy Web 生产构建脚本

cd "$(dirname "$0")/.."
echo "🔨 构建 ImBoy Web 应用（生产版本）..."
flutter build web --release --no-tree-shake-icons

if [ $? -eq 0 ]; then
  echo "✅ 构建成功！输出目录: build/web"
  echo ""
  echo "📦 预览构建结果："
  echo "   cd build/web && python3 -m http.server 9820"
  echo "   然后访问: http://localhost:9820"
else
  echo "❌ 构建失败"
  exit 1
fi
