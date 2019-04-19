import pynvim


@pynvim.plugin
class Neolsc():
    def __init__(self, nvim):
        self._nvim = nvim
        self._context = {}

        self._log = open('/tmp/xxx.txt', 'w+')

    def _debug(self, msg):
        print(msg, file=self._log, flush=True)

    @pynvim.function('_neolsc_init', sync=False)
    def init_channel(self, args):
        self._nvim.vars['neolsc_channel_id'] = self._nvim.channel_id

    @pynvim.rpc_export('neolsc_monitor_start')
    def _neolsc_monitor_start(self, buf):
        self._context[buf] = {'valid': False, 'lines': []}
        self._nvim.request('nvim_buf_attach', buf, True, {})
        self._debug('start monitoring {}: {}'.format(buf, self._context))

    @pynvim.rpc_export('neolsc_monitor_stop')
    def _neolsc_monitor_stop(self, buf):
        self._debug('stop monitoring {}'.format(buf))
        self._nvim.request('nvim_buf_detach', buf)

    @pynvim.rpc_export('nvim_buf_lines_event')
    def _on_buf_lines_event(self, *args):
        self._debug('nvim_buf_lines_event: {}'.format(args))
        buf, changedtick, firstline, lastline, linedata, more = args
        buf_nr = buf.number
        buf_ctx = self._context[buf_nr]

        if not buf_ctx['valid']:
            buf_ctx['lines'] = linedata
            buf_ctx['valid'] = True
            return

        head = buf_ctx['lines'][:firstline]
        chng = buf_ctx['lines'][firstline: lastline]
        tail = buf_ctx['lines'][lastline:]

        length = 0
        for l in chng:
            length += len(l) + 1

        buf_ctx['lines'] = head + linedata + tail

        assert([line.decode() for line in buf.api.get_lines(0, -1, True)]
               == buf_ctx['lines'])

        change_event = {
            'text': '\n'.join(linedata) + '\n',
            'rangeLength': length,
            'range': {
                'start': {'line': firstline, 'character': 0},
                'end': {'line': lastline, 'character': 0},
            }
        }

        if more:
            buf_ctx['events'] = buf_ctx.get('events', []) + [change_event]
            return

        # buffering all events for a while,
        # merge the events
        # doit(buf_ctx.pop('events'))

    @pynvim.rpc_export('nvim_buf_changedtick_event')
    def _on_buf_changedtick_event(self, *args):
        buf, changedtick = args
        self._debug(
            'nvim_buf_changedtick_event:[{}, {}]'.format(buf, changedtick))
        return

    @pynvim.rpc_export('nvim_buf_detach_event')
    def _on_nvim_buf_detach_event(self, *args):
        buf = args[0]
        self._context.pop(buf.number)
        self._debug('nvim_buf_detach_event:[{}]'.format(buf))
        return

