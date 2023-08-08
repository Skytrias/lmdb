package mdb

import "core:c"
import "core:mem"
import "core:strings"

when ODIN_OS == .Windows { foreign import lmdb { "mdb.lib", "system:Advapi32.lib" } }
when ODIN_OS == .Linux { foreign import lmdb { "liblmdb.a", "system:pthread" } }

env :: struct {}
txn :: struct {}
dbi :: c.uint
ID :: c.size_t

db :: struct {
	md_pad: c.uint32_t,    // also ksize for LEAF2 pages
	md_flags: c.uint16_t,  // @ref mdb_dbi_open
	md_depth: c.uint16_t,  // depth of this tree
	md_branch_pages: ID,   // number of internal pages
	md_leaf_pages: ID,     // number of leaf pages
	md_overflow_pages: ID, // number of overflow pages
	md_entries: c.size_t,  // number of data items
	md_root: ID,           // the root page of this tree
}

cmp_func :: proc "c" (a, b: ^val) -> c.int
rel_func :: proc "c" (item: ^val, oldptr, newptr, relctx: rawptr)
assert_func :: proc "c" (env: ^env, msg: cstring) 
msg_func :: proc "c" (msg: cstring, ctx: rawptr) -> c.int

dbx :: struct {
	md_name: val,
	md_cmp: cmp_func,
	md_dcmp: cmp_func,
	md_rel: rel_func,
	md_relctx: rawptr,
}

xcursor :: struct {
	mx_cursor: cursor,
	db: db,
	dbx: dbx,
	dbflag: c.uchar,
}

cursor :: struct {
	mc_next: ^cursor,
	mc_backup: ^cursor,
	mc_xcursor: ^xcursor,
	mc_txn: ^txn,
	mc_dbi: dbi,
	mc_db: ^db,
	mc_dbx: dbx,
	mc_dbflag: c.uchar,
	mc_snum: c.short,
	mc_top: c.short,
}

val :: struct {
	mv_size: c.size_t,
	mv_data: rawptr,
}

stat_t :: struct {
	ms_psize: c.uint,
	ms_depth: c.uint,
	ms_branch_pages: c.size_t,
	ms_leaf_pages: c.size_t,
	ms_overflow_pages: c.size_t,
	ms_entires: c.size_t,
}

envinfo :: struct {
	me_mapaddr: rawptr,
	me_mapsize: c.size_t,
	me_last_pgno: c.size_t,
	me_last_txnid: c.size_t,
	me_maxreaders: c.uint,
	me_numreaders: c.uint,
}

mode_t :: c.uint

// Environment Flags

// mmap at a fixed address (experimental)
FIXEDMAP :: 0x01
// no environment directory
NOSUBDIR :: 0x4000
// don't fsync after commit
NOSYNC :: 	0x10000
// read only
RDONLY :: 	0x20000
// don't fsync metapage after commit
NOMETASYNC :: 	0x40000
// use writable mmap
WRITEMAP :: 	0x80000
// use asynchronous msync when #MDB_WRITEMAP is used
MAPASYNC :: 	0x100000
// tie reader locktable slots to #MDB_txn objects instead of to threads
NOTLS :: 	0x200000
// don't do any locking, caller must manage their own locks
NOLOCK :: 	0x400000
// don't do readahead (no effect on Windows)
NORDAHEAD :: 0x800000
// don't initialize malloc'd memory before writing to datafile
NOMEMINIT :: 0x1000000

// Database flags

// use reverse string keys
REVERSEKEY :: 0x02
// use sorted duplicates
DUPSORT :: 0x04
// numeric keys in native byte order: either unsigned int or size_t.
// The keys must all be of the same size.
INTEGERKEY :: 0x08
// with #MDB_DUPSORT, sorted dup items have fixed size
DUPFIXED :: 0x10
// with #MDB_DUPSORT, dups are #MDB_INTEGERKEY-style integers
INTEGERDUP :: 0x20
// with #MDB_DUPSORT, use reverse string dups
REVERSEDUP :: 0x40
// create DB if not already existing
CREATE :: 0x40000

cursor_op :: enum c.int {
	// Position at first key/data item
	FIRST,				
	// Position at first data item of current key. Only for #DUPSORT
	FIRST_DUP,
	// Position at key/data pair. Only for #DUPSORT
	GET_BOTH,			
	// position at key, nearest data. Only for #DUPSORT
	GET_BOTH_RANGE,		
	// Return key/data at current cursor position
	GET_CURRENT,		
	// Return up to a page of duplicate data items
	// from current cursor position. Move cursor to prepare
	// for #NEXT_MULTIPLE. Only for #DUPFIXED
	GET_MULTIPLE,
	
	// Position at last key/data item
	LAST,				
	// Position at last data item of current key. Only for #DUPSORT
	LAST_DUP,

	// Position at next data item
	NEXT,				
	// Position at next data item of current key. Only for #DUPSORT
	NEXT_DUP,	

	// Return up to a page of duplicate data items.
	// from next cursor position. Move cursor to prepare
	// for #NEXT_MULTIPLE. Only for #DUPFIXED
	NEXT_MULTIPLE,		
	// Position at first data item of next key
	NEXT_NODUP,			
	// Position at previous data item
	PREV,				
	// Position at previous data item of current key. Only for #DUPSORT
	PREV_DUP,

	// Position at last data item of previous key
	PREV_NODUP,			
	// Position at specified key
	SET,				
	// Position at specified key, return key + data
	SET_KEY,			
	// Position at first key greater than or equal to specified key.
	SET_RANGE,			
	// Position at previous page and return up to
	// a page of duplicate data items. Only for #MDB_DUPFIXED 
	PREV_MULTIPLE,
}

@(default_calling_convention="c", link_prefix="mdb_")
foreign lmdb {
	// Return the LMDB library version information. 
	version :: proc(major, minor, patch: ^c.int) -> cstring ---
	
	// Return a string describing a given error code. 
	strerror :: proc(err: c.int) -> cstring ---

	// Create an LMDB environment handle. 
	env_create :: proc(env: ^^env) -> c.int ---
	// Open an environment handle. 
	env_open :: proc(env: ^env, path: cstring, flags: c.uint, mode: mode_t) -> c.int ---
	// Copy an LMDB environment to the specified path. 
	env_copy :: proc(env: ^env, path: cstring) -> c.int ---
	// Copy an LMDB environment to the specified file descriptor. 
	// env_copyfd :: proc(env: ^env, path: cstring) -> c.int --- // TODO
	// Copy an LMDB environment to the specified path, with options. 
	env_copy2 :: proc(env: ^env, path: cstring, flags: c.uint) -> c.int ---
	// Return statistics about the LMDB environment. 
	env_stat :: proc(env: ^env, stat: ^stat_t) -> c.int ---
	// Return information about the LMDB environment. 
	env_info :: proc(env: ^env, info: ^envinfo) -> c.int ---
	// Flush the data buffers to disk. 
	env_sync :: proc(env: ^env, force: b32) -> c.int ---
	// Close the environment and release the memory map. 
	env_close :: proc(env: ^env) ---
	// Set environment flags. 
	env_set_flags :: proc(env: ^env, flags: c.uint, onoff: b32) -> c.int ---
	// Get environment flags. 
	env_get_flags :: proc(env: ^env, flags: ^c.uint) -> c.int ---
	// Return the path that was used in mdb_env_open(). 
	env_get_path :: proc(env: ^env, path: ^cstring) -> c.int ---
	// Return the filedescriptor for the given environment. 
	// env_get_fd :: proc(env: ^env, fd: ) -> c.int --- // TODO
	// Set the size of the memory map to use for this environment. 
	env_set_mapsize :: proc(env: ^env, size: c.size_t) -> c.int ---
	// Set the maximum number of threads/reader slots for the environment. 
	env_set_maxreaders :: proc(env: ^env, readers: c.uint) -> c.int ---
	// Get the maximum number of threads/reader slots for the environment. 
	env_get_maxreaders :: proc(env: ^env, readers: ^c.uint) -> c.int ---
	// Set the maximum number of named databases for the environment. 
	env_set_maxdbs :: proc(env: ^env, dbs: dbi) -> c.int ---
	// Get the maximum size of keys and MDB_DUPSORT data we can write. 
	env_get_maxkeysize :: proc(env: ^env) -> c.int ---
	// Set application information associated with the MDB_env. 
	env_set_userctx :: proc(env: ^env, ctx: rawptr) -> c.int ---
	// Get the application information associated with the MDB_env. 
	env_get_userctx :: proc(env: ^env) -> rawptr ---
	// Set the environment assert callback
	env_set_assert :: proc(env: ^env, func: assert_func) -> c.int ---

	// Create a transaction for use with the environment. 
	txn_begin :: proc(env: ^env, parent: ^txn, flags: c.uint, txn: ^^txn) -> c.int ---
	// Returns the transaction's MDB_env. 
	txn_env :: proc(txn: ^txn) -> ^env ---
	// Return the transaction's ID. 
	txn_id :: proc(txn: ^txn) -> c.size_t ---
	// Commit all the operations of a transaction into the database. 
	txn_commit :: proc(txn: ^txn) -> c.int ---
	// Abandon all the operations of the transaction instead of saving them. 
	txn_abort :: proc(txn: ^txn) ---
	// Reset a read-only transaction. 
	txn_reset :: proc(txn: ^txn) ---
	// Renew a read-only transaction. 
	txn_renew :: proc(txn: ^txn) -> c.int ---

	// Open a database in the environment. 
	dbi_open :: proc(txn: ^txn, name: cstring, flags: c.uint, dbi: ^dbi) -> c.int ---
	// Retrieve statistics for a database. 
	// @(link_name="stat")
	stat :: proc(txn: ^txn, dbi: dbi, stat: ^stat_t) -> c.int ---
	// Retrieve the DB flags for a database handle. 
	dbi_flags :: proc(txn: ^txn, dbi: dbi, flags: c.uint) -> c.int ---
	// Close a database handle. Normally unnecessary. Use with care: 
	dbi_close :: proc(txn: ^txn, dbi: dbi) ---

	// Empty or delete+close a database. 
	drop :: proc(txn: ^txn, dbi: dbi, del: c.int) -> c.int ---

	// Set a custom key comparison function for a database. 
	set_compare :: proc(txn: ^txn, dbi: dbi, cmp: cmp_func) -> c.int ---
	// Set a custom data comparison function for a MDB_DUPSORT database. 
	set_dupsort :: proc(txn: ^txn, dbi: dbi, cmp: cmp_func) -> c.int ---
	// Set a relocation function for a MDB_FIXEDMAP database. 
	set_relfunc :: proc(txn: ^txn, dbi: dbi, rel: rel_func) -> c.int ---
	// Set a context pointer for a MDB_FIXEDMAP database's relocation function. 
	set_relctx :: proc(txn: ^txn, dbi: dbi, ctx: rawptr) -> c.int ---

	// Get items from a database. 
	get :: proc(txn: ^txn, dbi: dbi, key, data: ^val) -> c.int ---
	// Store items into a database. 
	put :: proc(txn: ^txn, dbi: dbi, key, data: ^val, flagsg: c.uint = 0) -> c.int ---
	// Delete items from a database. 
	del :: proc(txn: ^txn, dbi: dbi, key, data: ^val) -> c.int ---

	// Create a cursor handle. 
	cursor_open :: proc(txn: ^txn, dbi: dbi, cursor: ^^cursor) -> c.int ---
	// Close a cursor handle. 
	cursor_close :: proc(cursor: ^cursor) ---
	// Renew a cursor handle. 
	cursor_renew :: proc(txn: ^txn, cursor: ^cursor) -> c.int ---
	
	// Return the cursor's transaction handle. 
	cursor_txn :: proc(cursor: ^cursor) -> ^txn ---
	// Return the cursor's database handle. 
	cursor_dbi :: proc(cursor: ^cursor) -> dbi ---
	// Retrieve by cursor. 
	cursor_get :: proc(cursor: ^cursor, key, data: ^val, op: cursor_op) -> c.int ---
	// Store by cursor. 
	cursor_put :: proc(cursor: ^cursor, key, data: ^val, flags: c.uint) -> c.int ---
	// Delete current key/data pair. 
	cursor_del :: proc(cursor: ^cursor, flags: c.uint) -> c.int ---
	// Return count of duplicates for current key. 
	cursor_count :: proc(cursor: ^cursor, countp: ^c.size_t) -> c.int ---

	// Compare two data items according to a particular database. 
	cmp :: proc(txn: ^txn, dbi: dbi, a, b: ^val) -> c.int ---
	//  Compare two data items according to a particular database. 
	dcmp :: proc(txn: ^txn, dbi: dbi, a, b: ^val) -> c.int ---

	// Dump the entries in the reader lock table. 
	reader_list :: proc(env: ^env, func: msg_func, ctx: rawptr) -> c.int ---
	// Check for stale entries in the reader lock table. 
	reader_check :: proc(env: ^env, dead: ^c.int) -> c.int ---
}

// create a val from a str
val_str_make :: proc(str: string) -> val {
	return { len(str), raw_data(str) }
}

// create a val from a data source and its size
val_data_make :: proc(data: rawptr, size: int) -> val {
	return { uint(size), data }
}

// create a val from a byte slice
val_bytes_make :: proc(slice: []byte) -> val {
	return { len(slice), raw_data(slice) }
}

// create a val from a typed pointer
val_typed_make :: proc(data: ^$T) -> val {
	return { size_of(T), data }
}

// get a string from a val (no copy)
val_str_get :: proc(val: val) -> string {
	return strings.string_from_ptr(cast(^byte) val.mv_data, int(val.mv_size))
}

// get a typed result from an input val - sizes need to match
val_typed_get :: proc(val: val, $T: typeid) -> (res: T) {
	assert(val.mv_size == size_of(T))
	res = (cast(^T) val.mv_data)^
	return
}

// get a typed slice from an input val - returns {} on 0 size
val_slice_get :: proc(val: ^val, $T: typeid) -> (res: []T) {
	slice_count := val.mv_size / size_of(T)
	if slice_count > 0 {
		res = mem.slice_ptr(cast(^T) val.mv_data, int(slice_count))
	} 
	return
}
