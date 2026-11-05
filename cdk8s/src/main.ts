import path from 'node:path';
import { synth } from './synth';

synth(process.env.CDK8S_OUTDIR ?? path.resolve(__dirname, '../../kubernetes/dist'));
