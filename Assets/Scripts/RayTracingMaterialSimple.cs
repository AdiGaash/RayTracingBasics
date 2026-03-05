using UnityEngine;

[System.Serializable]
public struct RayTracingMaterialSimple
{
	public Color colour;

	public void SetDefaultValues()
	{
		colour = Color.white;
	}
}
