copyProject
===========

Utility script to copy a project and associated documents from one
sharelatex database to another, given the project id

Example
-------

    $ coffee copyProject.coffee --from="mongodb://localhost:27017/sharelatex" --to="mongodb://localhost:27017/sharelatex-test" 54899d081ddd78e2491e75ca

will copy project 54899d081ddd78e2491e75ca from the mongo database
`sharelatex` to `sharelatex-test` on `localhost`

To send the data to stdout, omit the target database

    $ coffee copyProject.coffee --from="mongodb://localhost:27017/sharelatex" 54899d081ddd78e2491e75ca > log

This can be useful for comparing project states before and after an
operation.

Notes
-----

Starting from the given project in the `projects` collection, the
script finds the associated documents and users by walking the objects
looking for ObjectIds and copies their data.  The following minimal
set of collections are handled, enough to load up a document and check
its history.

   - projects
   - projectHistoryMetaData
   - docHistory
   - docs   (for all documents found in the project history)
   - docOps (for all documents found in the project history)
   - users  (for all associated users found in document history)

Note: the script is destructive, any entries already present in the
destination `to` database are removed before being inserted.

If you need to copy from a mongo database on a remote machine, use an
ssh tunnel to make it available on a local port such as 9999.

    $ ssh -L 9999:localhost:27017 -N remotehost