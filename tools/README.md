# Exercise animation tools

The stick-figure demonstrations in the app are data, not images. They are authored in Python so the joint geometry
(inverse kinematics for hands and feet planted on the floor) can be solved and previewed without Xcode.

```sh
pip install pillow
cd tools
python3 export.py                       # regenerates Momentum/Design/MotionData.swift
python3 run_film.py /tmp/out.png motions_a,motions_b,motions_c   # filmstrip of every keyframe
python3 check_interp.py /tmp/mid.png pushup burpee                # keyframes + in-between poses
```

- `skeleton.py`: forward kinematics + two-bone IK. Must stay in sync with `Skeleton` in `Momentum/Design/FigureView.swift`.
- `motions_a/b/c.py`: keyframes per exercise (`motion(id, frames, ...)`). Every exercise in `data/exercises.json` needs one; `export.py` fails otherwise.
- Angles are degrees from straight down (0 = down, 90 = toward +x / facing right, 180 = up). World is y-up, floor at y = 0.
