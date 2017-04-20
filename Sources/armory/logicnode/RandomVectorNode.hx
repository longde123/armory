package armory.logicnode;

import armory.math.Vec4;

class RandomVectorNode extends LogicNode {

	var v = new Vec4();

	public function new(tree:LogicTree) {
		super(tree);
	}

	override function get(from:Int):Dynamic {
		var min:Vec4 = inputs[0].get();
		var max:Vec4 = inputs[1].get();
		var x = min.x + (Math.random() * (max.x - min.x));
		var y = min.y + (Math.random() * (max.y - min.y));
		var z = min.z + (Math.random() * (max.z - min.z));
		v.set(x, y, z);
		return v;
	}
}