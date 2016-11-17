#!/usr/bin/env coffee

ductile = require './ductile'
{join, sep} = require 'path'
log  = require 'bog'

log.redirect console.error, console.error
log.level 'warn'

readfile = (f) ->
    path = if f[0] == sep then f else join(process.cwd(), f)
    try
        require(path)
    catch ex
        if ex.code == 'MODULE_NOT_FOUND'
            console.error "File not found: #{path}"
            process.exit -1
        else
            throw ex

yargs = require('yargs').usage('\nUsage: ductile <command> [options] <url>')

.strict()
.wrap(null)

.command
    command: 'export [options] <url>'
    aliase:  'e'
    desc:    'Bulk export items',
    builder: (yargs) ->
        yargs
        .strict()
        .usage('\nUsage: ductile export [options] <url>')
        .option 'd',
            alias:    'delete'
            default:  false
            describe: 'output delete operations'
            type:     'boolean'
        .option 'q',
            alias:    'query'
            describe: 'file with json query'
            type:     'string'
        .option 't',
            alias:    'transform'
            describe: 'file with transform function'
            type:     'string'
        .demand(1)
    handler: (argv) ->
        odelete = argv["delete"]
        body = readfile(argv.q) if argv.q
        trans = if argv.t then readfile(argv.t) else (v) -> v
        lsearch = {body}
        ductile(argv.url)
        .reader(lsearch, odelete, trans)
        .on 'progress', (p) ->
            console.error "Exported #{p.from}/#{p.total}"
        .on 'error', (err) ->
            console.error 'EXPORT ERROR:', err.message
        .pipe(process.stdout)
        .on 'error', (err) ->
            if err.code == 'EPIPE'
                # broken pipe
                process.exit -1
            else
                console.error 'EXPORT ERROR:', err

.command
    command: 'import [options] <url>'
    aliase:  'i'
    desc:    'Bulk import items',
    builder: (yargs) ->
        yargs
        .strict()
        .usage '\nUsage: ductile import [options] <url>'
        .option 'd',
            alias:    'delete'
            default:  false
            describe: 'change incoming index operations to delete'
            type:     'boolean'
        .option 't',
            alias:    'transform'
            describe: 'file with transform function'
            type:     'string'
        .demand(1)
    handler: (argv) ->
        odelete = argv["delete"]
        trans = if argv.t then readfile(argv.t) else (v) -> v
        ductile(argv.url)
        .writer(odelete, trans, process.stdin)
        .on 'progress', (p) ->
            console.error "Imported #{p.count}"
        .on 'error', (err) ->
            console.error 'IMPORT ERROR:', err.message
            process.exit -1


.example 'ductile export http://localhost:9200/myindex'
.example 'ductile export http://localhost:9200/myindex/mytype > dump.bulk'
.example 'ductile import http://localhost:9200/myindex/mytype < dump.bulk'
.help()
.showHelpOnFail()

argv = yargs.argv

unless argv._.length
    yargs.showHelp()