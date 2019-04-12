# protoype-hubot-getJiraAttachments
hubot + slack連携のJIRA添付画像取得処理のプロトタイプ

* jql検索結果issueに添付されている画像を保存
* jql検索結果issueの要約を加工し、tsvファイルに書き出し
* zipファイルに圧縮し、指定slackroomへ添付

##### npm module
* forever
* fs
* archiver
* child_process
* date-utils
* sync-request
* iconv-lite
* jszip

##### api
* Jira REST API
* slack api files.upload

##### test server
* AWS EC2