using System.Collections.Generic;
using UnityEngine;
using static UnityEngine.Mathf;

[ExecuteAlways, ImageEffectAllowedInSceneView]
public class RayTracingSphereManagerSimple : MonoBehaviour
{

	[Header("References")]
	[SerializeField] Shader rayTracingShader;
	[SerializeField] Shader accumulateShader;

	

	[Header("Info")]
	[SerializeField] int numRenderedFrames;
	[SerializeField] int numSpheres;

	// Materials and render textures
	Material rayTracingMaterial;
	Material accumulateMaterial;
	RenderTexture resultTexture;

	// Buffers
	ComputeBuffer sphereBuffer;

	void Start()
	{
		numRenderedFrames = 0;
	}

	// Called after any camera (e.g. game or scene camera) has finished rendering into the src texture
	void OnRenderImage(RenderTexture src, RenderTexture target)
	{
		InitFrame();

		// Create copy of prev frame
		RenderTexture prevFrameCopy = RenderTexture.GetTemporary(src.width, src.height, 0, ShaderHelper.RGBA_SFloat);
		Graphics.Blit(resultTexture, prevFrameCopy);

		// Run the ray tracing shader and draw the result to a temp texture
		rayTracingMaterial.SetInt("Frame", numRenderedFrames);
		RenderTexture currentFrame = RenderTexture.GetTemporary(src.width, src.height, 0, ShaderHelper.RGBA_SFloat);
		Graphics.Blit(null, currentFrame, rayTracingMaterial);

		// Accumulate
		accumulateMaterial.SetInt("_Frame", numRenderedFrames);
		accumulateMaterial.SetTexture("_PrevFrame", prevFrameCopy);
		Graphics.Blit(currentFrame, resultTexture, accumulateMaterial);

		// Draw result to screen
		Graphics.Blit(resultTexture, target);

		// Release temps
		RenderTexture.ReleaseTemporary(currentFrame);
		RenderTexture.ReleaseTemporary(prevFrameCopy);

		numRenderedFrames += Application.isPlaying ? 1 : 0;
	}

	void InitFrame()
	{
		// Create materials used in blits
		ShaderHelper.InitMaterial(rayTracingShader, ref rayTracingMaterial);
		ShaderHelper.InitMaterial(accumulateShader, ref accumulateMaterial);
		// Create result render texture
		ShaderHelper.CreateRenderTexture(ref resultTexture, Screen.width, Screen.height, FilterMode.Bilinear, ShaderHelper.RGBA_SFloat, "Result");

		// Update data
		UpdateCameraParams(Camera.current);
		CreateSpheres();
	}

	void UpdateCameraParams(Camera cam)
	{
		float focusDistance = 1.0f; // Fixed distance
		float planeHeight = focusDistance * Tan(cam.fieldOfView * 0.5f * Deg2Rad) * 2;
		float planeWidth = planeHeight * cam.aspect;
		// Send data to shader
		rayTracingMaterial.SetVector("ViewParams", new Vector3(planeWidth, planeHeight, focusDistance));
		rayTracingMaterial.SetMatrix("CamLocalToWorldMatrix", cam.transform.localToWorldMatrix);
	}

	void CreateSpheres()
	{
		// Create sphere data from the sphere objects in the scene
		RayTracedSphereSimple[] sphereObjects = FindObjectsOfType<RayTracedSphereSimple>();
		SphereSimple[] spheres = new SphereSimple[sphereObjects.Length];

		for (int i = 0; i < sphereObjects.Length; i++)
		{
			spheres[i] = new SphereSimple()
			{
				position = sphereObjects[i].transform.position,
				radius = sphereObjects[i].transform.localScale.x * 0.5f,
				material = sphereObjects[i].material
			};
		}

		// Create buffer containing all sphere data, and send it to the shader
		ShaderHelper.CreateStructuredBuffer(ref sphereBuffer, spheres);
		rayTracingMaterial.SetBuffer("Spheres", sphereBuffer);
		rayTracingMaterial.SetInt("NumSpheres", sphereObjects.Length);

		numSpheres = sphereObjects.Length;
	}

	void OnDisable()
	{
		ShaderHelper.Release(sphereBuffer);
		ShaderHelper.Release(resultTexture);
	}
}
