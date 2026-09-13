import { defineConfig } from 'vite';
import { fileURLToPath } from 'node:url';
export default defineConfig({root:fileURLToPath(new URL('.',import.meta.url)),build:{outDir:'../../../.local/visual-hub/web-dist',emptyOutDir:true},cacheDir:'../../../.local/visual-hub/vite-cache',envDir:false});
