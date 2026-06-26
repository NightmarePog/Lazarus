--- this file exists only so EmmyLua dosen't emit errors in spec
---@meta

--- The `has_no` negation chain (e.g. `assert.has_no.errors(fn)`).
---@class luassert.has_no
---@field errors fun(fn: fun(), msg?: string)

--- The `is_not` negation chain (e.g. `assert.is_not.equal(a, b)`).
---@class luassert.is_not
---@field equal fun(expected: any, actual: any, msg?: string)
---@field same  fun(expected: any, actual: any, msg?: string)

---@class luassert
---@overload fun(v: any, msg?: string): any
---@field equal       fun(expected: any, actual: any, msg?: string)
---@field same        fun(expected: any, actual: any, msg?: string)
---@field is_true     fun(value: any, msg?: string)
---@field is_false    fun(value: any, msg?: string)
---@field is_truthy   fun(value: any, msg?: string)
---@field is_nil      fun(value: any, msg?: string)
---@field is_not_nil  fun(value: any, msg?: string)
---@field is_number   fun(value: any, msg?: string)
---@field is_string   fun(value: any, msg?: string)
---@field is_boolean  fun(value: any, msg?: string)
---@field is_function fun(value: any, msg?: string)
---@field is_table    fun(value: any, msg?: string)
---@field has_error   fun(fn: fun(), msg?: string)
---@field has_no      luassert.has_no
---@field is_not      luassert.is_not
---@field matches     fun(pattern: string, str: any, msg?: string)
---@field not_matches fun(pattern: string, str: any, msg?: string)
---@field not_nil     fun(value: any, msg?: string)
---@field no_errors   fun(fn: fun(), msg?: string)

---@type luassert
---@diagnostic disable
assert = assert

---@type fun(name: string, block: fun())
describe = describe

---@type fun(name: string, block: fun())
it = it

---@type fun(fn: fun())
before_each = before_each

---@type fun(fn: fun())
after_each = after_each

---@type fun(fn: fun())
setup = setup

---@type fun(fn: fun())
teardown = teardown

---@type fun(name?: string)
pending = pending
