mongojs = require "mongojs"
ObjectId = mongojs.ObjectId
async = require "async"
util = require 'util'
_ = require 'underscore'
argv = require('minimist')(process.argv.slice(2))
usage = () ->
	console.log 'coffee copyProject.coffee --from=[MONGOURL] --to=[MONGOURL] PROJECT_ID'
	process.exit()
usage() if argv._.length != 1

project_id = ObjectId(argv._[0])
console.log 'copying project', project_id

collections = ["projects", "users", "docs", "docOps", "docHistory", "projectHistoryMetaData"]
dbOld = mongojs.connect argv.from, collections
dbNew = mongojs.connect argv.to, collections if argv.to?

# walk an object from mongo looking for object ids, call 'action' when an objectid is found
walk = (obj, path, action) ->
	val = if typeof obj == 'string' && obj.match(/^[0-9a-f]{24}$/) then ObjectId(obj )else obj
	if val instanceof ObjectId
		return action val, path
	else if _.isArray val
		_.each val, (v, i) ->
			walk v, path + '[' + i + ']', action
	else if _.isObject val
		_.each val, (v, k) ->
			walk v, path + '.' + k, action if k != 'lines'
	else
		return

docids = []
docids_seen = {}
userids = []
userids_seen = {}
# action to handle cross-references to users and docs
docAction = (obj, path) ->
	id = obj.toString()
	if path.match(/docs\[\d+\]\._id$/) or path.match(/\.rootDoc_id$/) or path.match(/doc_id$/)
		return if docids_seen[id]
		docids.push obj
		docids_seen[id] = true
	else if path.match(/\.owner_ref$/) or path.match(/user_id$/)
		return if userids_seen[id]
		userids.push obj
		userids_seen[id] = true

copyFromCollection = (collection, query, callback) ->
	console.log 'copying', collection, query
	dbOld[collection].find(query).sort {_id:1}, (err, doc) ->
		if doc.length == 0 # early return, if no docs found
			if dbNew?
				dbNew[collection].remove query, (err, result) ->
					callback(err,result)
				return
			else
				return callback(err)
		else
			walk doc, collection, docAction
			if dbNew?
				dbNew[collection].remove query, (err, result) ->
					return callback(err) if err?
					dbNew[collection].insert doc, (err, result) ->
						return callback(err, result)
			else
				console.log doc
				return callback(err)

projectQuery = {project_id:project_id}

copyFromCollection 'projects', {_id:project_id}, (err, doc) ->
	async.series [
		(callback) ->
			copyFromCollection('projectHistoryMetaData', projectQuery, callback)
		(callback) ->
			async.eachSeries docids.sort(), (doc_id, cb) ->
				copyFromCollection('docs', {_id:doc_id}, cb)
			, callback
		(callback) ->
			async.eachSeries docids.sort(), (doc_id, cb) ->
				copyFromCollection('docOps', {doc_id:doc_id}, cb)
			, callback
		(callback) ->
			async.eachSeries docids.sort(), (doc_id, cb) ->
				copyFromCollection('docHistory', {doc_id:doc_id}, cb)
			, callback
		(callback) ->
			async.eachSeries userids.sort(), (id, callback) ->
				copyFromCollection('users', {_id:id}, callback)
			, callback
	], (err, result) ->
		if err?
			console.log 'mongo error:', err
		else
			console.log 'done'
		dbOld.close()
		dbNew.close() if dbNew?
