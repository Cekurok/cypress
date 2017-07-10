_ = require("lodash")
Promise = require("bluebird")

$Log = require("../../cypress/log")
utils = require("../../cypress/utils")

exec = (options) =>
  new Promise (resolve, reject) ->
    Cypress.trigger "exec", options, (resp) ->
      if err = resp.__error
        err.timedout = resp.timedout
        reject(err)
      else
        resolve(resp)

module.exports = (Commands, Cypress, cy) ->
  Commands.addAll({
    exec: (cmd, options = {}) ->
      _.defaults options,
        log: true
        timeout: Cypress.config("execTimeout")
        failOnNonZeroExit: true
        env: {}

      if options.log
        consoleOutput = {}

        options._log = $Log.command({
          message: _.truncate(cmd, { length: 25 })
          consoleProps: ->
            consoleOutput
        })

      if not cmd or not _.isString(cmd)
        utils.throwErrByPath("exec.invalid_argument", {
          onFail: options._log,
          args: { cmd: cmd ? '' }
        })

      options.cmd = cmd

      ## need to remove the current timeout
      ## because we're handling timeouts ourselves
      @_clearTimeout()

      isTimedoutError = (err) -> err.timedout

      exec(_.pick(options, "cmd", "timeout", "env"))
      .timeout(options.timeout)
      .then (result) ->
        if options._log
          _.extend(consoleOutput, { Yielded: _.omit(result, "shell") })

          consoleOutput["Shell Used"] = result.shell

        return result if result.code is 0 or not options.failOnNonZeroExit

        output = ""
        output += "\nStdout:\n#{_.truncate(result.stdout, { length: 200 })}" if result.stdout
        output += "\nStderr:\n#{_.truncate(result.stderr, { length: 200 })}" if result.stderr

        utils.throwErrByPath "exec.non_zero_exit", {
          onFail: options._log
          args: { cmd, output, code: result.code }
        }

      .catch Promise.TimeoutError, isTimedoutError, (err) ->
        utils.throwErrByPath "exec.timed_out", {
          onFail: options._log
          args: { cmd, timeout: options.timeout }
        }

      .catch (error) ->
        ## re-throw if timedout error from above
        throw error if error.name is "CypressError"

        utils.throwErrByPath("exec.failed", {
          onFail: options._log
          args: { cmd, error }
        })
  })
