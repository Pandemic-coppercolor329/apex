# Apex — Parallelized system updater for Linux (Arch, Flatpak, Snap).

## STRATEGY (minimize wall-clock time, without racing anything unsafe):
   1. **pacman downloads all official-repo updates WITHOUT installing** (-w).
      This is the only phase that's guaranteed to compete for your download
      bandwidth, so nothing else starts until it's finished.

   2. **The instant that download finishes**, two things start at once:

        a) **pacman installs the already-downloaded packages** (disk/CPU only,
           no network)

        b) your **AUR helper (yay/paru) starts resolving + cloning + building**
           AUR updates

   3. **As soon as the AUR helper finishes** its upfront dependency
      resolution/cloning burst and starts actually building packages, we
      **start flatpak, then snap, one after another** — all while pacman's
      install and the AUR build keep running in the background.

   4. Everything is joined at the end and a summary is printed.

 Anything you don't have installed (yay/paru, flatpak, snap) is skipped
 automatically.
 
 ## HOW STEP 3 IS DETECTED
   Both yay and paru shell out to the real `makepkg` binary to build
   packages. makepkg's very first line of output for any package is
   always:
       ==> Making package: <name> <version> (<date>)
   That line is emitted by makepkg itself (not the AUR helper), and has
   been stable across versions for years — it's a much steadier target
   than parsing yay/paru's own wrapper output. We watch the AUR helper's
   log for the first occurrence of that line and treat it as "the bulk
   download burst (dependency resolution + AUR git clones) is done, real
   building has started" — a reasonable, if not perfectly exact, proxy.
   Per-package source downloads inside individual builds can still trickle
   in after this point; those are typically small next to compile time, so
   the residual bandwidth overlap is an acceptable trade for not blocking
   flatpak/snap on the *entire* AUR job.
   To make sure that line is always in English no matter your system
   locale, we force LC_ALL=C for just that one subprocess.
   
   > If you'd rather not rely on this heuristic at all, pass --conservative
   to wait for the whole AUR job to finish before starting flatpak/snap.

 ## SAFETY NOTES
   - To run the AUR helper unattended, this script auto-accepts
     diffs/prompts (--noconfirm + answer flags). You lose the manual
     "review the PKGBUILD" step. Review AUR packages separately/
     periodically if that matters to you.
   - In theory, pacman's install step and the AUR helper's own final
     `pacman -U` could both want the pacman DB lock at once. In practice
     this essentially never happens, since building AUR packages takes far
     longer than installing already-cached repo packages — but if you ever
     see "unable to lock database", just re-run the script.

