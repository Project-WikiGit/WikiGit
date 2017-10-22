IPFS = require 'ipfs'
node = new IPFS()
node.on('ready',
  () ->
    node.files.cat('QmYThycWdzRuVKJ3maPKmEBxANQX9z66AjEzRpZ55i7gaf',
      (err, file) ->
        console.log(err)
    )
    node.stop(
      () ->

    )
)