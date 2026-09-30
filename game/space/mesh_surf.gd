class_name MeshSurf
extends RefCounted
## 程序化网格累加器：往里塞顶点与三角形，提交 / 合并时统一校正绕序并算法线。
## Godot 的正面绕序为顺时针（与内置 SphereMesh 一致），按"右手系直觉"生成网格会被
## 背面剔除、看起来像翻面；这里用闭合曲面的 ∮(x-c)·n dA = 3V 判据自动校正绕序，
## 并按同一约定算法线，因此镜像件 / 倾斜件的法线也都朝外。

var verts := PackedVector3Array()
var idx := PackedInt32Array()
var cols := PackedColorArray()


func v(p: Vector3, col := Color(1.0, 1.0, 1.0)) -> int:
	verts.append(p)
	cols.append(col)
	return verts.size() - 1


func tri(a: int, b: int, c: int) -> void:
	idx.append(a)
	idx.append(b)
	idx.append(c)


func quad(a: int, b: int, c: int, d: int) -> void:
	tri(a, b, c)
	tri(a, c, d)


## 先校正零件自身绕序，再并入本网格。
func merge(other: MeshSurf) -> void:
	other.fix_winding()
	var off := verts.size()
	verts.append_array(other.verts)
	cols.append_array(other.cols)
	for i in other.idx:
		idx.append(i + off)


func commit() -> ArrayMesh:
	var m := ArrayMesh.new()
	if idx.size() < 3 or verts.size() < 3:
		return m
	fix_winding()
	var nrm := PackedVector3Array()
	nrm.resize(verts.size())
	for i in range(0, idx.size(), 3):
		var a := idx[i]
		var b := idx[i + 1]
		var c := idx[i + 2]
		# 正面绕序为顺时针，法线取反向叉积
		var n := (verts[c] - verts[a]).cross(verts[b] - verts[a])
		nrm[a] += n
		nrm[b] += n
		nrm[c] += n
	for i in nrm.size():
		nrm[i] = nrm[i].normalized() if nrm[i].length_squared() > 0.0 else Vector3.UP
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_INDEX] = idx
	if cols.size() == verts.size():
		arr[Mesh.ARRAY_COLOR] = cols
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## 闭合曲面上 ∮(x-c)·n dA = 3V，为负说明整体绕反，逐个三角形翻转。
func fix_winding() -> void:
	var c := Vector3.ZERO
	for p in verts:
		c += p
	c /= float(verts.size())
	var acc := 0.0
	for i in range(0, idx.size(), 3):
		var a := idx[i]
		var b := idx[i + 1]
		var d := idx[i + 2]
		var n := (verts[d] - verts[a]).cross(verts[b] - verts[a])
		acc += n.dot((verts[a] + verts[b] + verts[d]) / 3.0 - c)
	if acc < 0.0:
		for i in range(0, idx.size(), 3):
			var t: int = idx[i + 1]
			idx[i + 1] = idx[i + 2]
			idx[i + 2] = t
