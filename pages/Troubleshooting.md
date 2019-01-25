# Troubleshooting

## Common issues

### Errors when incrementing counters
If you see an `argument error` while incrementing a counter, it's likely
to be to do with ETS - in most cases, the application might not have started
correctly. To fix this, you must either specify `:instruments` in the
`extra_applications` section of your mix.exs file. To fully resolve this issue,
you need to remove `applications` from your mix.exs and move all of them into
`extra_applications` - this means that libraries that start automatically will
be able to.

### Your statsd doesn't seem to be aggregating the metrics sent by Instruments
1. Check to see if your :statix configuration in your config.exs has the correct port and hostname
2. Make sure the `reporter_module` in the Instruments config is set to `Instruments.Statix`

## Anything else?
Create an issue!