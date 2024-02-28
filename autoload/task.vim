vim9script

export class AsyncCmd
    var job: job

    def Stop(how: string = '')
        if this.job->job_status() ==# 'run'
            how->empty() ? this.job->job_stop() : this.job->job_stop(how)
        endif
    enddef

    def new(cmd: any, CallbackFn: func(string), env: dict<any> = null_dict)
        # ch_logfile('/tmp/channellog', 'w')
        # ch_log('BuildItemsList call')
        var start = reltime()
        var items = []
        this.Stop('kill')
        this.job = job_start(cmd, {
            close_cb: (chan: channel) => {
                var msg = []
                while chan->ch_status({'part': 'out'}) == 'buffered'
                    msg->add(chan->ch_read())
                endwhile
                CallbackFn(msg->join())
            },
            err_cb: (chan: channel, msg: string) => {
                :echohl ErrorMsg | echoerr $'error: {msg} from {cmd}' | echohl None
            },
            exit_cb: (jb, status) => {
                if status != 0
                    :echohl ErrorMsg | echoerr $'{cmd} exited with status {status}' | echohl None
                endif
            }
        }->extend(env != null_dict ? {env: env} : {}))
    enddef
endclass
