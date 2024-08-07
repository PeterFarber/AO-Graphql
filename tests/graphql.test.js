import { test } from 'node:test'
import * as assert from 'node:assert'
import AoLoader from '@permaweb/ao-loader'
import fs from 'fs'

const wasm = fs.readFileSync('./process.wasm')
const options = { format: "wasm64-unknown-emscripten-draft_2024_02_15" }

test('graphql', async () => {
    const handle = await AoLoader(wasm, options)
    const env = {
        Process: {
            Id: 'AOS',
            Owner: 'FOOBAR',
            Tags: [
                { name: 'Name', value: 'Thomas' }
            ]
        }
    }
    const msg = {
        Target: 'AOS',
        From: 'FOOBAR',
        Owner: 'FOOBAR',
        ['Block-Height']: "1000",
        Id: "1234xyxfoo",
        Module: "WOOPAWOOPA",
        Tags: [
            { name: 'Action', value: 'Eval' }
        ],
        Data: `
local luagraphqlparser = require('luagraphqlparser')
local res = luagraphqlparser.parse('query { hello }')
return res
`
    }

    // load handler
    const result = await handle(null, msg, env)

    console.log(result)

    assert.ok(true)
})
