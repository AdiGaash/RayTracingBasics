Shader "Custom/RayTracingSpheres"
{
	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

		// --- Settings and constants ---
		static const float PI = 3.1415;

		// Camera Settings
		float3 ViewParams;
		float4x4 CamLocalToWorldMatrix;
			
		// Lighting Settings
		float4 AmbientLight;
		
			
			
			// --- Structures ---
			struct Ray
			{
				float3 origin;
				float3 dir;
			};
			
			struct RayTracingMaterial
			{
				float4 colour;
			};

			struct Sphere
			{
				float3 position;
				float radius;
				RayTracingMaterial material;
			};

			struct HitInfo
			{
				bool didHit;
				float dst;
				float3 hitPoint;
				float3 normal;
				RayTracingMaterial material;
			};

			// --- Buffers ---	
			StructuredBuffer<Sphere> Spheres;
			int NumSpheres;

			// --- Ray Intersection Functions ---
		
			/// Calculate the intersection of a ray with a sphere
			/// Uses the quadratic formula to solve for ray-sphere intersection
			/// A ray is defined as: P(t) = O + t*D where O is origin, D is direction, t is distance
			/// A sphere is defined as: |P - C|^2 = r^2 where C is center, r is radius
			/// Substituting ray equation into sphere equation gives a quadratic in t
			HitInfo RaySphere(Ray ray, float3 sphereCentre, float sphereRadius)
			{
				HitInfo hitInfo = (HitInfo)0;
				
				// Vector from sphere center to ray origin
				float3 offsetRayOrigin = ray.origin - sphereCentre;
				
				// Quadratic equation coefficients: at^2 + bt + c = 0
				// From: |O + t*D - C|^2 = r^2
				// Expanded: |O - C + t*D|^2 = r^2
				// (O-C + t*D) · (O-C + t*D) = r^2
				// |O-C|^2 + 2t(O-C)·D + t^2|D|^2 = r^2
				// t^2|D|^2 + 2t(O-C)·D + (|O-C|^2 - r^2) = 0
				
				float a = dot(ray.dir, ray.dir);                                      // Usually 1 for normalized dir
				float b = 2.0 * dot(offsetRayOrigin, ray.dir);
				float c = dot(offsetRayOrigin, offsetRayOrigin) - sphereRadius * sphereRadius;
				
				// Discriminant: b^2 - 4ac
				// If < 0: no intersection
				// If = 0: tangent (ray touches sphere at one point)
				// If > 0: two intersections (ray enters and exits sphere)
				float discriminant = b * b - 4.0 * a * c;

				if (discriminant >= 0.0)
				{
					// Use quadratic formula: t = (-b ± sqrt(discriminant)) / 2a
					// We want the NEAREST intersection (smallest positive t)
					// So we use the minus sign: t = (-b - sqrt(discriminant)) / 2a
					float sqrtDiscriminant = sqrt(discriminant);
					float dst = (-b - sqrtDiscriminant) / (2.0 * a);

					// Only count intersections in front of the ray (dst >= 0)
					if (dst >= 0.0)
					{
						hitInfo.didHit = true;
						hitInfo.dst = dst;
						hitInfo.hitPoint = ray.origin + ray.dir * dst;
						// Normal at hit point points from center outward
						hitInfo.normal = normalize(hitInfo.hitPoint - sphereCentre);
					}
				}
				return hitInfo;
			}

			
		// --- Ray Intersection Functions ---

		/// Calculate if a ray hits any sphere (for shadow testing)
		/// Returns true if ray is blocked by any sphere, false if clear path
		bool IsInShadow(Ray shadowRay, float maxDistance)
		{
			// Check intersection with each sphere
			for (int i = 0; i < NumSpheres; i++)
			{
				Sphere sphere = Spheres[i];
				HitInfo hitInfo = RaySphere(shadowRay, sphere.position, sphere.radius);

				// If we hit something between the hit point and light, we're in shadow
				if (hitInfo.didHit && hitInfo.dst > 0.001 && hitInfo.dst < maxDistance)
				{
					return true; // Shadow ray blocked
				}
			}
			return false; // Clear path to light
		}

		/// Find the closest sphere intersection for a given ray
		/// Iterates through all spheres and finds the nearest hit
		HitInfo CalculateRayCollision(Ray ray)
		{
			HitInfo closestHit = (HitInfo)0;
			closestHit.dst = 1.#INF; // Initialize to infinity (no hit)

			// Check intersection with each sphere
			for (int i = 0; i < NumSpheres; i++)
			{
				Sphere sphere = Spheres[i];
				HitInfo hitInfo = RaySphere(ray, sphere.position, sphere.radius);

				// Update closest hit if this hit is closer
				if (hitInfo.didHit && hitInfo.dst < closestHit.dst)
				{
					closestHit = hitInfo;
					closestHit.material = sphere.material;
				}
			}

			return closestHit;
		}

	/// Main ray tracing function - Lambert Diffuse with shadows
	/// Simple direct lighting with shadow ray testing
	float3 Trace(Ray ray)
	{
		HitInfo hitInfo = CalculateRayCollision(ray);

		if (hitInfo.didHit)
		{
			// Ambient light component - base illumination
			float3 ambientContribution = AmbientLight.rgb * AmbientLight.a;
			
			// Lambert diffuse: dot product of normal with light direction
			float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
			float lambertFactor = max(0.0, dot(hitInfo.normal, lightDir));
			
			// Shadow ray calculation
			float shadowFactor = 1.0; // Default: no shadow
			if (lambertFactor > 0.0) // Only cast shadow ray if surface faces light
			{
				// Create shadow ray from hit point towards light
				Ray shadowRay;
				shadowRay.origin = hitInfo.hitPoint + hitInfo.normal * 0.001; // Small offset to avoid self-intersection
				shadowRay.dir = lightDir;
				
				// Calculate distance to light (assuming directional light at infinite distance)
				float lightDistance = 1000.0; // Large distance for directional light
				
				// Check if shadow ray hits any sphere
				if (IsInShadow(shadowRay, lightDistance))
				{
					shadowFactor = 0.2; // Partial shadow - still some light gets through
				}
			}
			
			float3 diffuseContribution = hitInfo.material.colour.rgb * lambertFactor * shadowFactor;
			
			// Combine ambient and diffuse lighting
			float3 finalColor = (ambientContribution + diffuseContribution) * hitInfo.material.colour.rgb;
			
			return finalColor;
		}
		else
		{
			// No hit - return ambient background color
			return AmbientLight.rgb * AmbientLight.a * 0.5; // Dimmed for background
		}
	}

		// --- Fragment Shader ---
		
		/// Main fragment shader - runs once per pixel
		/// Shoots a single ray and calculates Lambert diffuse lighting
		float4 frag (v2f i) : SV_Target
		{
			// Setup camera geometry
			float3 focusPointLocal = float3(i.uv - 0.5, 1.0) * ViewParams;
			float3 focusPoint = mul(CamLocalToWorldMatrix, float4(focusPointLocal, 1.0));
			
			

			// Create single ray from camera to focal point
			Ray ray;
			ray.origin = _WorldSpaceCameraPos;
			ray.dir = normalize(focusPoint - ray.origin);
			
			// Trace the ray
			float3 pixelCol = Trace(ray);
			return float4(pixelCol, 1.0);
		}

			ENDCG
		}
	}
}

