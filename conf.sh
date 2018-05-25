#!/bin/sh
OLD_PO_DIR="${HOME}/gitroot/emacs-26.0.rc1-doc-emacs/"
NEW_DOC_DIR="${HOME}/work/emacs/doc/emacs/"
WORK_DIR="./"
COMPENDIUM="${WORK_DIR}/compendium.po"
UPDATE_NEW_DOCS_CMD="git fetch ${NEW_DOC_DIR}/../.."
COMMIT_COMPENDIUM_CMD="git add -A; git commit -m 'update compendium'; git push -u origin master"
PUBLISH_LOC="${HOME}/gitroot/ayatakesi.github.io/emacs/"

eval ${UPDATE_NEW_DOCS_CMD}

rm -i ${COMPENDIUM}

for TEXI in $(ls ${NEW_DOC_DIR}/*.texi)
do
    F=$(basename ${TEXI})
    POT="${WORK_DIR}/${F}.pot"
    OLD_PO="${OLD_PO_DIR}/${F}.po"        
    NEW_PO="${WORK_DIR}/${F}.po"

    if [ -f ${OLD_PO} ] ; then
	po4a-gettextize -M utf8 -f texinfo \
			-m ${TEXI} -p ${POT}
	
	msgmerge --previous --compendium ${OLD_PO} \
		 -o ${NEW_PO} /dev/null ${POT}

	FUZZY=$(mktemp)
	msgattrib -o ${FUZZY} --only-fuzzy ${NEW_PO}
	
	UNTRANS=$(mktemp)
	msgattrib -o ${UNTRANS} --untranslated ${NEW_PO}

	msgcat -o - --no-wrap -F ${FUZZY} ${UNTRANS} \
	       >> ${NEW_PO}.compendium
       
	rm -f ${FUZZY} ${UNTRANS}
	
    fi

done

msgcat *.compendium  > ${COMPENDIUM}
rm -f *.compendium

msgcat --no-wrap --color=html ${COMPENDIUM} > ${COMPENDIUM}.html
cd ${PUBLISH_LOC}
cp ${COMPENDIUM}.html ${PUBLISH_LOC}
eval ${COMMIT_COMPENDIUM_CMD}
