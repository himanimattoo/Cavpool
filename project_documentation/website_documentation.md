# Cavpool Website

Official website for Cavpool - Safe Campus Transportation

## Deployment Instructions

### Deploy to Vercel

1. Install Vercel CLI:
   ```bash
   npm i -g vercel
   ```

2. Deploy from this directory:
   ```bash
   cd website
   vercel
   ```

3. Follow the prompts:
   - Set up and deploy? **Y**
   - Which scope? (choose account)
   - Link to existing project? **N**
   - Project name: **cavpool-website**
   - Directory: **./website** (if not already in website directory)

4. The site will be deployed and a URL like: `https://cavpool-website.vercel.app` will be provided

### Alternative: Deploy via Vercel Dashboard

1. Go to [vercel.com](https://vercel.com)
2. Sign up/login with GitHub
3. Click "New Project"
4. Import the repository
5. Set the root directory to `website`
6. Deploy

## Local Development

To run locally:
```bash
npx serve .
```

Then open http://localhost:3000

## Files

- `index.html` - Main homepage
- `privacy.html` - Privacy policy (required for Stripe)
- `styles.css` - All styling
- `vercel.json` - Vercel deployment configuration
- `package.json` - Project metadata

## Features

- Responsive design
- Professional appearance
- Privacy policy for compliance
- Contact information
- Mobile-friendly
- Fast loading
- SEO optimized