# FreeSurfer License Setup

## You Need a FreeSurfer License (Free)

FreeSurfer requires a **free license file** to run. Here's how to get it:

### Step 1: Register for FreeSurfer License

1. Go to: https://surfer.nmr.mgh.harvard.edu/registration.html
2. Fill out the registration form (takes 2 minutes)
3. You'll receive an email with a `license.txt` file attached

### Step 2: Save the License File

Once you receive the license via email:

```bash
# Save the license.txt file to this directory:
cp /path/to/your/downloaded/license.txt /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/freesurfer_license/license.txt
```

Or create it manually in this directory as `license.txt` with the content from the email.

### Step 3: Verify License

```bash
cat /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/freesurfer_license/license.txt
```

The file should look like:
```
your-email@institution.edu
12345
*your-key-here*
your-key-continues
```

### Alternative: Use Existing License

If you already have a FreeSurfer license somewhere on your system:

```bash
# Copy it to the required location
cp /path/to/existing/license.txt /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/freesurfer_license/license.txt
```

## Once License is in Place

After you have the license file, you can run the MELD pipeline:

```bash
cd /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/meld_graph
./run_meld_with_freesurfer.sh -id <subject_id>
```

## Common License Locations to Check

```bash
# Check common locations where FreeSurfer license might already exist:
find ~ -name "license.txt" 2>/dev/null
find /usr/local/freesurfer -name "license.txt" 2>/dev/null
```

## Need Help?

FreeSurfer license is completely **FREE** and provided by MGH/Harvard.

- Registration: https://surfer.nmr.mgh.harvard.edu/registration.html
- FreeSurfer support: https://surfer.nmr.mgh.harvard.edu/fswiki/FreeSurferSupport

**Note**: The license registration is instant and free. You just need to provide your name and email.



