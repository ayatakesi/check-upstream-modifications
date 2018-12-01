#!/bin/sh
# 内部SD逼迫のため外部SDにリポジトリ作成
LOCAL_REPOSITORY_DIR="/data/data/com.termux/files/home/storage/external-1/gitroot/emacs"
DOCUMENT_FILES_SUBDIR="doc/emacs"
DOCUMENT_FILES="*.texi"

# カレントバージョン
CURR_VERSION=${1}

# 突合先ブランチ
NEW_VERSION_BRANCH=${2}

# 当リポジトリと兄弟のローカルリポジトリを参照
CURR_PO_FILES_DIR="$(pwd)/../emacs-${CURR_VERSION}-doc-emacs"
PUBLISH_TO_DIR="$(pwd)/../ayatakesi.github.io"

WORK_DIR="$(pwd)/work"
rm -fr ${WORK_DIR} && mkdir -p ${WORK_DIR}

# 対象ブランチをフェッチ
cd ${LOCAL_REPOSITORY_DIR}
git checkout ${NEW_VERSION_BRANCH}
git pull

# ヘッダーを作成
cat <<EOF > ${WORK_DIR}/header.txt
This file was updated $(date)
  by branch ${NEW_VERSION_BRANCH}'s HEAD.
EOF

# 対象ブランチHEADのドキュメントを作業ディレクトリーにコピー
rm -fr ${WORK_DIR}/${DOCUMENT_FILES_SUBDIR} &&
    mkdir -p ${WORK_DIR}/${DOCUMENT_FILES_SUBDIR}

cp ${LOCAL_REPOSITORY_DIR}/${DOCUMENT_FILES_SUBDIR}/${DOCUMENT_FILES} ${WORK_DIR}/${DOCUMENT_FILES_SUBDIR}

for TEXI in $(ls ${WORK_DIR}/${DOCUMENT_FILES_SUBDIR}/${DOCUMENT_FILES})
do
    FNAME=$(basename ${TEXI})
    
    # ドキュメントファイルをHTMLに変換
    source-highlight -f html --line-number-ref -i ${TEXI} -o ${WORK_DIR}/${FNAME}.html

    # ドキュメントファイルのPOTファイル作成
    po4a-gettextize -M utf8 \
		    -f texinfo \
		    -m ${TEXI} \
		    -p ${TEXI}.pot
    
    # 翻訳済みカレントPOと未訳POTを突合して更新版PO作成
    msgmerge --previous \
	     --compendium ${CURR_PO_FILES_DIR}/${FNAME}.po \
	     -o ${TEXI}.po /dev/null ${TEXI}.pot

    # 更新版POからFUZZYと未訳を抽出
    FUZZY=$(mktemp)
    msgattrib -o ${FUZZY} --only-fuzzy ${TEXI}.po
	    
    UNTRANS=$(mktemp)
    msgattrib -o ${UNTRANS} --untranslated ${TEXI}.po

    msgcat -o ${WORK_DIR}/${FNAME}.compendium ${FUZZY} ${UNTRANS}
    rm -f ${FUZZY} ${UNTRANS}
    
done

# 全ドキュメントの未訳FUZZYを結合
# PO headerは読み飛ばす
msgcat --width=80 \
       --sort-by-file \
       ${WORK_DIR}/*.compendium |
    perl -ne 'BEGIN{$/="\n\n"}{print ($.>1 ? STDOUT : STDERR);}' \
	 > ${WORK_DIR}/compendium.pot 2>${WORK_DIR}/header.po

# HTMLに変換
source-highlight \
    -f html \
    -H ${WORK_DIR}/header.txt \
    -i ${WORK_DIR}/compendium.pot \
    -o ${WORK_DIR}/compendium.po.html

# リンクタグ設定
perl -pe \
     "s{${WORK_DIR}/${DOCUMENT_FILES_SUBDIR}/([^:]+):(\d+)}{<a href=\1.html#line\2>\1:\2</a>}" \
     -i ${WORK_DIR}/compendium.po.html

# ウェブサイトにパブリッシュ
S="${PUBLISH_TO_DIR}/emacs/${CURR_VERSION}/diff_from_${NEW_VERSION_BRANCH}"
rm -fr $S
mkdir $S
cp ${WORK_DIR}/*.html $S
cd ${PUBLISH_TO_DIR}
git add -A
git commit -m "diff-ing at $(date)"
git push -u origin master

