// Creates local-only signed installer input. Never uploads or changes a save.
// Usage: node Testing/MonthlyContent/prepare-reader-rehearsal.mjs /private/tmp/monthly-reader-input
import { readFile, writeFile, mkdir, copyFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { createHash, generateKeyPairSync, sign } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const output = resolve(process.argv[2] ?? '/private/tmp/monthly-reader-input');
await mkdir(output, { recursive: true });
const now = new Date();
const start = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 8);
const end = new Date(start); end.setDate(end.getDate() + 30);
const residue = new Date(end); residue.setDate(residue.getDate() + 3);
const foreshadow = new Date(start); foreshadow.setDate(foreshadow.getDate() - 2);
const casebook = new Date(residue); casebook.setDate(casebook.getDate() + 7);
const pack = JSON.parse(await readFile(join(root, 'docs/fixtures/monthly-rehearsal/school-door.reenchantedevents.json')));
pack.authoringManifests[0].id = 'school-door-simulator';
Object.assign(pack.events[0].calendar, { startYear: start.getFullYear(), startMonth: start.getMonth() + 1, startDay: start.getDate() });
pack.marginalia[0].assetPackID = 'school-door-art';
pack.marginalia[0].assetID = 'school-door-goblin';
// A separate disposable leaf lets the same Book test Trash without erasing
// its completed lesson or manufacturing a second Reader's history.
const looseLeaf = structuredClone(pack.authoringManifests[0].content.find(x => x.id === 'opening'));
Object.assign(looseLeaf, { id: 'loose-leaf', title: 'Loose practice leaf', priority: 'featured',
  reference: { kind: 'storyScene', id: 'loose-leaf' },
  placement: { lifecycleStage: 'live', phaseID: 'inside-the-page', phaseRole: 'buildup' } });
pack.authoringManifests[0].content.push(looseLeaf);
pack.storyScenes.push({ id: 'loose-leaf', packID: pack.id, eventID: pack.events[0].id,
  title: 'A Spare Leaf', opening: 'I grew a spare leaf. Nothing is waiting behind it. You may let it go.',
  prompt: 'Keep this leaf, or let it go.', detail: 'Issue Zero: a disposable rehearsal leaf.',
  choices: [], entities: ['The Book'], tags: ['rehearsal'] });
const readingLeaf = structuredClone(looseLeaf);
Object.assign(readingLeaf, { id: 'reading-leaf', title: 'Reading-only practice leaf',
  reference: { kind: 'storyScene', id: 'reading-leaf' } });
pack.authoringManifests[0].content.push(readingLeaf);
pack.storyScenes.push({ id: 'reading-leaf', packID: pack.id, eventID: pack.events[0].id,
  title: 'The Door Takes a Bow', opening: 'The door bows on its new hinge. Nobody taught it that. I suspect the curtain.',
  prompt: 'Keep this leaf.', detail: 'Issue Zero: a reading-only rehearsal leaf.',
  choices: [], entities: ['The Book'], tags: ['rehearsal'] });
const audioAtom = structuredClone(pack.authoringManifests[0].content.find(x => x.id === 'radio-hinge'));
audioAtom.id = 'radio-recorded'; audioAtom.title = 'Recorded fixture bulletin'; audioAtom.reference.id = 'radio-recorded';
pack.authoringManifests[0].content.push(audioAtom);
const audioCoverage = pack.authoringManifests[0].coverageRequirements.find(x => x.id === 'radio');
audioCoverage.minimumReady = 2; audioCoverage.maximumReady = 2;
pack.radioBanters.push({ ...structuredClone(pack.radioBanters[0]), id: 'radio-recorded', banter: {
  id: 'radio-recorded', category: 'stationID', assetName: '{{asset-path:school-door-audio-v1}}', weight: 1,
  caption: "You've reached Fae-Fi. Eighty-eight point three on the Academy band. I keep the records here. Today's record is: the pixies are fine, the pixies are too fine, please send help. Anyway. Music."
} });
const art = {
  id: 'school-door-art', displayName: 'Issue Zero file-backed art', version: '1', author: 'ReEnchanted',
  availability: 'userImported', supportedTemplates: [], backgrounds: [], paperScraps: [], stamps: [],
  doodles: [{ id: 'school-door-goblin', assetName: '{{asset-path:school-door-image-v1}}', kind: 'doodle',
    tags: ['rehearsal'], supportedTemplates: [], defaultOpacity: 1, canTint: false }],
  tape: [], overlays: [], fallbackPhrases: []
};
const pages = { id: 'school-door-art', displayName: art.displayName, version: 1, author: art.author,
  availability: 'userImported', archetypes: [], marginaliaPack: art };
await writeFile(join(output, 'school-door.reenchantedevents.json'), JSON.stringify(pack, null, 2));
await writeFile(join(output, 'school-door.reenchantedpack.json'), JSON.stringify(pages, null, 2));
await copyFile(join(root, 'InsideCoverApp/Assets.xcassets/MarginaliaGoblinQuestioning.imageset/MarginaliaGoblinQuestioning.png'), join(output, 'school-door-goblin.png'));
await copyFile(join(root, 'InsideCoverApp/RadioAudio/DJ_faefi_id_01.m4a'), join(output, 'school-door-radio.m4a'));
const assets = [];
for (const [id, kind, fileName] of [
  ['school-door-runtime-v1', 'worldEventPack', 'school-door.reenchantedevents.json'],
  ['school-door-art-v1', 'pageArchetypePack', 'school-door.reenchantedpack.json'],
  ['school-door-image-v1', 'media', 'school-door-goblin.png'],
  ['school-door-audio-v1', 'media', 'school-door-radio.m4a']
]) {
  const bytes = await readFile(join(output, fileName));
  assets.push({ id, kind, fileName, scope: 'runtime', remoteURL: `https://rehearsal.invalid/${fileName}`,
    sha256: createHash('sha256').update(bytes).digest('hex'), byteCount: bytes.length, isRequired: true });
}
const manifest = { schemaVersion: 1, generatedAt: now.toISOString(), allowedAssetHosts: ['rehearsal.invalid'],
  issues: [{ id: 'school-door-simulator', packID: pack.id, title: pack.displayName,
    liveStartsAt: start.toISOString(), liveEndsAt: end.toISOString(), foreshadowStartsAt: foreshadow.toISOString(),
    residueEndsAt: residue.toISOString(), casebookAvailableAt: casebook.toISOString(), assets }] };
const payload = Buffer.from(JSON.stringify(manifest));
const keys = generateKeyPairSync('ed25519');
await writeFile(join(output, 'public-key.bin'), keys.publicKey.export({ type: 'spki', format: 'der' }).subarray(-32));
await writeFile(join(output, 'manifest.envelope.json'), JSON.stringify({ keyID: 'simulator-only',
  payload: payload.toString('base64'), signature: sign(null, payload, keys.privateKey).toString('base64') }));
console.log(`Prepared ${assets.length} local assets in ${output}. Current phase: BUILDUP. No files uploaded.`);
