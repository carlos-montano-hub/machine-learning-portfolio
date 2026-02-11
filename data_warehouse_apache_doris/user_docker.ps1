# docker pull yagagagaga/doris-standalone
& docker run -d --name doris-standalone `
    -p 8030:8030 `
    -p 9030:9030 `
    yagagagaga/doris-standalone

Write-Output "Doris standalone instance is running."