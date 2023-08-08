# Lightning Memory-Mapped Database Manager (LMDB)
[lmdb](http://www.lmdb.tech/doc/index.html) bindings for [odin](https://odin-lang.org/)

# Basic Example
```odin
package main

import "core:fmt"
import "../mdb"

check :: proc(err: i32, loc := #caller_location) {
    if err != 0 {
        fmt.eprintln(loc, "ERR val", err)
        fmt.eprintln("\tERR str", mdb.strerror(err))
    }
}

main :: proc() {
    fmt.eprintln(mdb.version(nil, nil, nil))

    // open or create an lmdb environment
    env: ^mdb.env
    check(mdb.env_create(&env))
    check(mdb.env_set_mapsize(env, 10485760)) // 10 MB map size
    check(mdb.env_open(env, "save.lmdb", mdb.NOSUBDIR, 0o0664))

    // begin a write transaction
    txn: ^mdb.txn
    check(mdb.txn_begin(env, nil, mdb.WRITEMAP, &txn))
    dbi: mdb.dbi
    check(mdb.dbi_open(txn, nil, 0, &dbi))

    key, data: mdb.val

    // // write some values (for testing only once to see persistent read)
    // fmt.eprintln("PUT")
    // key = mdb.val_str("testing")
    // data = mdb.val_str("Hello World")
    // check(mdb.put(txn, dbi, &key, &data))
    // key = mdb.val_str("another")
    // data = mdb.val_str("one")
    // check(mdb.put(txn, dbi, &key, &data))

    check(mdb.txn_commit(txn))
    
    // prep read
    check(mdb.txn_begin(env, nil, mdb.RDONLY, &txn))
    check(mdb.dbi_open(txn, nil, 0, &dbi))

    cursor: ^mdb.cursor
    mdb.cursor_open(txn, dbi, &cursor)
    for mdb.cursor_get(cursor, &key, &data, .NEXT) == 0 {
        fmt.eprintf("\tKEY: %v = VALUE: %v\n", key.mv_data, data.mv_data)
    }
    mdb.cursor_close(cursor)
    
    mdb.txn_abort(txn)
    mdb.env_close(env)
}
```

# License
Not sure wether the License needs to be the same as the [original](https://www.openldap.org/software/release/license.html) as it's just bindings (with docs copied). Let me know if it has to match. 
