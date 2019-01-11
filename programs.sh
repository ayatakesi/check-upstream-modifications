#!/bin/sh
# 内部SD逼迫のため外部SDにリポジトリ作成
LOCAL_REPOSITORY_DIR="/data/data/com.termux/files/home/storage/external-1/gitroot/emacs"
DOCUMENT_FILES_SUBDIR="doc/emacs"
DOCUMENT_FILES="*.texi"

# カレントバージョン
CURR_VERSION=${1}

# 結合先ブランチ
NEW_VERSION_BRANCH=${2}

# 更新済compendium
TRANSLATED_COMPENDIUM=${3}

# 当リポジトリと兄弟のローカルリポジトリを参照
CURR_PO_FILES_DIR="$(pwd)/../emacs-${CURR_VERSION}-doc-emacs"
PUBLISH_TO_DIR="$(pwd)/../ayatakesi.github.io"

WORK_DIR="$(pwd)/work"
rm -fr ${WORK_DIR} && mkdir -p ${WORK_DIR}

# 対象ブランチをフェッチ
cd ${LOCAL_REPOSITORY_DIR}
git checkout ${NEW_VERSION_BRANCH}
git pull
cd -

# ヘッダーを作成
cat <<EOF > ${WORK_DIR}/header.txt
This file was updated $(date)<br>
  by branch ${NEW_VERSION_BRANCH}'s HEAD.<br>
<br>
Here is a msgfmt's output (with -v option). <br>
EOF

# 対象ブランチHEADのドキュメントを作業ディレクトリーにコピー
rm -fr ${WORK_DIR}/${DOCUMENT_FILES_SUBDIR} &&
    mkdir -p ${WORK_DIR}/${DOCUMENT_FILES_SUBDIR}

cp ${LOCAL_REPOSITORY_DIR}/${DOCUMENT_FILES_SUBDIR}/${DOCUMENT_FILES} ${WORK_DIR}/${DOCUMENT_FILES_SUBDIR}

for TEXI in $(ls ${WORK_DIR}/${DOCUMENT_FILES_SUBDIR}/${DOCUMENT_FILES})
do
    FNAME=$(basename ${TEXI})
    
    # ドキュメントファイルのPOTファイル作成
    rm -f ${TEXI}.pot
    po4a-gettextize -M utf8 \
		    -f texinfo \
		    -m ${TEXI} \
		    -p ${TEXI}.pot

    if [ -e ${CURR_PO_FILES_DIR}/${FNAME}.po ]; then
	if [ -n "${TRANSLATED_COMPENDIUM}" ]; then
	    msgcat ${CURR_PO_FILES_DIR}/${FNAME}.po \
		   ${TRANSLATED_COMPENDIUM} > translated.po
	else
	    cp ${CURR_PO_FILES_DIR}/${FNAME}.po translated.po
	fi
	
	# 翻訳済みカレントPOと未訳POTを結合して更新版PO作成
	msgmerge --previous \
		 --no-wrap \
		 --compendium translated.po \
		 -o ${TEXI}.po /dev/null ${TEXI}.pot

	# 更新版POからFUZZYと未訳を抽出
	FUZZY=$(mktemp)
	msgattrib -o ${FUZZY} --only-fuzzy ${TEXI}.po
	
	UNTRANS=$(mktemp)
	msgattrib -o ${UNTRANS} --untranslated ${TEXI}.po

	msgcat -o ${WORK_DIR}/${FNAME}.compendium ${FUZZY} ${UNTRANS}
	rm -f ${FUZZY} ${UNTRANS}
    fi
    source-highlight -f html --line-number-ref -i ${TEXI} -o ${WORK_DIR}/${FNAME}.html
done

# 全ドキュメントの未訳FUZZYを結合
msgcat --width=80 \
       --sort-by-file \
       ${WORK_DIR}/*.compendium \
       > ${WORK_DIR}/compendium.pot

# 統計情報取得
msgfmt -v ${WORK_DIR}/compendium.pot >>${WORK_DIR}/header.txt 2>&1

# poにリンク種をセット
emacs -q --batch \
      --eval '(setq my-po-file "work/compendium.pot")' \
      --load $(pwd)/create_anchor.el

# PO headerは読み飛ばす
msgcat --width=80 \
       --sort-by-file \
       ${WORK_DIR}/compendium.pot |
    perl -ne 'BEGIN{$/="\n\n"}{if ($.>1) {print STDOUT} else {print STDERR};}' \
	 > ${WORK_DIR}/compendium.po 2>${WORK_DIR}/header.po

# HTMLに変換
source-highlight \
    -f html \
    -H ${WORK_DIR}/header.txt \
    -i ${WORK_DIR}/compendium.po \
    -o ${WORK_DIR}/compendium.po.html

# 種からリンクを設定
perl -pe '
     my $line = $_;
     if ($line =~ m{^(.+)# ([^.]+).([^:]+):(\d+)(.+)$}) {
     	 my $linkstr = $1 . "# <a href=" . $2 . "." . $3 . "_" . $4 . ".html>変更内容</a>です。";
	 $linkstr = $linkstr . $5 . "\n";
	 s/$line/$linkstr/;
      }' \
     -i ${WORK_DIR}/compendium.po.html


# texiソースへのリンク設定
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

