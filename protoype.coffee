module.exports = (robot) ->
  fs = require 'fs'
  request  = require 'sync-request'
  archiver = require 'archiver'
  exec  = require('child_process').exec
          require 'date-utils'
  iconv = require 'iconv-lite'
  JSZip = require 'jszip'
  domain = 'domain'

  slackMsgstr = (str) ->
    return '`'+str+'`'

  FILE_JIRA_USER_PASSWORD_CSV = './set_values/jira_user_password.csv'
  jirauserpassword = fs.readFileSync FILE_JIRA_USER_PASSWORD_CSV, "utf-8"
  jiraUserInfocells = jirauserpassword.split ","
  jirauser = jiraUserInfocells[0]
  jirapassword = jiraUserInfocells[1]
  authdata = new Buffer(jirauser + ':' + jirapassword).toString('base64')
  FILE_JQL_TXT = './set_values/jql.txt'
  FILE_TOKEN_TXT = './set_values/token.txt'
  fstoken = fs.readFileSync FILE_TOKEN_TXT, "utf-8"
  token = fstoken.trim()
  sendfile  = 'example.zip'
  slackRoom = ''

  robot.respond /keyword (.*),(.*)/i, (res) ->
    arrimgNm = []
    arrattachment = []
    fileNames = []

    zip = new JSZip()
    pathto    = ''
    tsvNm     = ''
    tsvfileNm = ''

    dt        = new Date()
    formatted = dt.toFormat("YYYYMMDDHH24MI")
    pathto    = './'+formatted+'/'
    tsvNm     = formatted + 'tst.tsv'
    tsvfileNm = pathto + tsvNm

    mkdir = (path, data) ->
      fs.mkdir path,(err) ->
        if err
          throw err
        return
      return
    mkdir pathto, ''

    writeFile = (path, data) ->
      fs.writeFile path, data, (err) ->
        if err
          throw err
        return
      return
    writeFile tsvfileNm, ''

    unlink = (path) ->
      fs.unlink path, (err) ->
        if err
          throw err
        return
      return

    rtnJql = (res) =>
      ->
        fromDateStr = res.match[1]
        toDateStr = res.match[2]
        now = new Date
        years = now.getFullYear()
        fromDate    = '>= ' + fromDateStr
        toDate      = '<= ' + toDateStr
        jql = fs.readFileSync(FILE_JQL_TXT, "utf-8")
        jqlReplaced = jql.replace(/>=?\x20\d{4}-\d{1,2}-\d{1,2}/g , fromDate).replace(/<=?\x20\d{4}-\d{1,2}-\d{1,2}/g , toDate)
        FILE_TSV_TXT = tsvfileNm
        TSV = fs.readFileSync FILE_TSV_TXT, "utf-8"
        url = domain+'rest/api/latest/search/?jql=' + encodeURIComponent(jqlReplaced)
        response = request('GET', url, {headers: {Authorization: 'Basic ' + authdata}})
        if response.statusCode != 200
          d = new Date
          console.log  "#{d.getFullYear()}年#{d.getMonth() + 1}月#{d.getDate()}日#{d.getHours()}時#{d.getMinutes()}分#{d.getSeconds()}秒"
          console.log 'JQL発行時、httpStatusCodeに' + response.statusCode + 'が返ってきたため終了します'
          return
        jsonData = ''
        try
          jsonData = JSON.parse(response.getBody('utf8'))
        catch e
          console.log e
          return
        if jsonData.issues.length != 0
          for issue,idx in jsonData.issues
            summary = jsonData.issues[idx].fields.summary
            key     = jsonData.issues[idx].key
            cnt = summary + '\u0009' + key + '\n'
            fs.appendFileSync tsvfileNm, cnt

            id = jsonData.issues[idx].id
            arrattachment.push(id)

    getimg = (obj) =>
      ->
        for id,idx in obj
          url1 = domain + 'rest/api/2/issue/' + id
          response1 = request('GET', url1, {headers: {Authorization: 'Basic ' + authdata}})

          if response1.statusCode != 200
            d = new Date
            console.log e
            return

          jsonData = ''
          try
            jsonData = JSON.parse(response1.getBody('utf8'))
          catch e
            console.log e
            return

          if jsonData.id.length != 0
            for attachments,i in jsonData.fields.attachment
              imgurl   = attachments.content
              filename = attachments.filename
              filedir  = pathto + filename
              found = arrimgNm.find((element) ->
                element == filename
              )

              response2 = request('GET', imgurl, {headers: {Authorization: 'Basic ' + authdata}})
              if idx is 0
                arrimgNm.push(filename)
                fileNames.push(filename)
                fs.writeFileSync filedir, response2.body, 'binary'
              else if found is undefined
                arrimgNm.push(filename)
                fileNames.push(filename)
                fs.writeFileSync filedir, response2.body, 'binary'
          else
            console.log e
            return

    cns = () =>
      setTimeout ->
        sendZip()
      , 500

    createZip = () =>
      getStream = (fileName) ->
        fs.readFileSync fileName
      fileNames.push(tsvNm)

      i = 0
      while i < fileNames.length
        path = pathto + fileNames[i]
        zip.file fileNames[i], getStream(path)
        i++
      zip.generateNodeStream(
        streamFiles: true
        compression: 'DEFLATE'
        encodeFileName: (fileName) ->
          iconv.encode fileName, 'CP932'
      ).pipe(fs.createWriteStream(sendfile)).on 'finish', ->
      return

    sendZip = () =>
      cmd = 'curl -F "filename='+sendfile+'" -F file=@'+sendfile+' -F "channels=' + slackRoom + '" -F "token='+token+'" https://slack.com/api/files.upload'
      exec cmd, (error, stdout, stderr) ->
        if error != null
          throw stderr
        else
          obj = JSON.parse(stdout)

    removeDirFile = () =>
      targetDir = fs.readdirSync pathto
      for file,i in targetDir
        fs.unlinkSync pathto + targetDir[i]

    removeDir = () =>
      setTimeout ->
        fs.rmdirSync formatted
      , 500

    promise = Promise.resolve()
    promise
      .then(rtnJql res)
      .then(getimg arrattachment)
      .then(cns)
      .then(removeDirFile)
      .then(removeDir)
