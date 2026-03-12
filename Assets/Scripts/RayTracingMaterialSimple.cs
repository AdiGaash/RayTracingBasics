using UnityEngine;

[System.Serializable]
public struct RayTracingMaterialSimple
{
	public Color colour;
	public float reflectance; // How reflective the material is (0 = no reflection, 1 = mirror)

	public void SetDefaultValues()
	{
		colour = Color.white;
		reflectance = 0.5f;
	}
}
