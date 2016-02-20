var child_process = require('child_process'),
    path          = require('path');

var command = ['apm install', process.argv[2]].join(' ');

var paths = process.env.PATH.split(path.delimiter);

if (paths.indexOf('/usr/local/bin') === -1) {
    paths.push('/usr/local/bin');
}

process.env.PATH = paths.join(path.delimiter);

process.stdout.write(child_process.execSync(command));
