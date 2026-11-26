#!/bin/sh
# 말씀 상고 웹앱 → GitHub Pages 배포 스크립트
# 사용: sh deploy.sh            (REPO=owner/name, 기본 darameee2/malssum-counter)
set -e
REPO="${REPO:-darameee2/malssum-counter}"
OWNER="${REPO%%/*}"
NAME="${REPO##*/}"
cd "$(dirname "$0")"

echo "== 1. 저장소 확인/생성: $REPO"
if gh api "repos/$REPO" >/dev/null 2>&1; then
  echo "   이미 존재합니다."
else
  if gh repo create "$REPO" --public --description "말씀 상고 10회 카운트 웹앱" >/dev/null 2>&1; then
    echo "   생성 완료."
  else
    echo "   저장소 생성 실패: 이 GitHub 연결(GitHub App 설치)에 저장소 생성 권한이 없습니다."
    echo "   → 사용자가 github.com/new 에서 빈 공개 저장소 '$NAME'을 만들면 이 스크립트를 다시 실행하세요."
    exit 2
  fi
fi

echo "== 2. 커밋/푸시"
if [ ! -d .git ]; then git init -q; git branch -M main; fi
git add -A
git -c user.name="$OWNER" -c user.email="$OWNER@users.noreply.github.com" commit -q -m "말씀 상고 10회 카운트 웹앱 배포" || echo "   (변경 없음)"
git push -f "https://github.com/$REPO.git" HEAD:main
# 이 GitHub 연결(GitHub App)은 Pages 설정 권한이 없어 API로 소스를 바꿀 수 없다.
# gh-pages 브랜치를 푸시하면 GitHub이 그 브랜치를 Pages 소스로 자동 배포한다(실제 라이브 소스).
git push -f "https://github.com/$REPO.git" HEAD:gh-pages

echo "== 3. GitHub Pages 활성화 (branch gh-pages, path /)"
gh api -X POST "repos/$REPO/pages" -f "source[branch]=gh-pages" -f "source[path]=/" >/dev/null 2>&1 \
  && echo "   활성화 요청 완료" \
  || gh api "repos/$REPO/pages" -q '.html_url' 2>/dev/null || echo "   Pages 활성화 실패(권한 확인 필요)"

echo "== 4. 응답 확인 (최대 5분)"
URL="https://${OWNER}.github.io/${NAME}/"
i=0
while [ $i -lt 30 ]; do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' "$URL" || true)
  echo "   [$i] $URL -> $CODE"
  [ "$CODE" = "200" ] && { echo "== 배포 완료: $URL"; exit 0; }
  i=$((i+1)); sleep 10
done
echo "== 아직 200이 아닙니다. Pages 빌드 로그: gh api repos/$REPO/pages/builds/latest"
exit 1
