
1. tcchecklst.sh: it checks if new updates has been released because they might
                  change the dependencies (tc??-??-deps.db.gz). However, the
                  compressed files could differ despite the content is the
                  same due to a difference in meta-data compression (e.g. date).

2. tcupdatedb.sh: it downloads the TCZs database which is necessary for queries
                  about packages content: who provide what. 

3. tcprovides.sh: it queries the TCZs database about packages content.

4. tcdownload.sh: it downloads a single TCZ packages and related information.

5. tcgetdistro.sh: it downloads all the TCZ packages and system files that are
                   needed to create the image

6. tcdepends.sh: it shows the dependencies of a specific TCZ package.

7. tcmkdepsdb.sh: it creates the dependencies database for the current system
                  architecture (tc??-??-deps.db.gz). Check, if it is needed by
                  running tcchecklst.sh first.

