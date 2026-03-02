using System.Collections;
using UnityEngine;
using UnityEngine.UI;

public class TrialBehaviour : MonoBehaviour
{
    [Header("References")]
    [SerializeField] private RawImage cueImage;
    [SerializeField] private RawImage stimulusImage;

    private float stimuliFrequency;
    private float stimuliDuration;
    private Coroutine trialRoutine;
    public void SetTrialParameters(float frequency, float duration)
    {
        stimuliFrequency = frequency;
        stimuliDuration = duration;
    }
    private void OnEnable()
    {
        trialRoutine = StartCoroutine(TrialRoutine());
    }
    private void OnDisable()
    {
        if (trialRoutine != null)
        {
            StopCoroutine(trialRoutine);
            trialRoutine = null;
        }
    }
    public IEnumerator TrialRoutine()
    {
        float elapsed = 0f;
        float halfPeriod = 1f / (2f * stimuliFrequency);

        while (elapsed < stimuliDuration)
        {
            stimulusImage.color = Color.white;
            float phaseStart = elapsed;
            while (elapsed - phaseStart < halfPeriod)
            {
                elapsed += Time.deltaTime;
                yield return null;
            }

            stimulusImage.color = Color.black;
            phaseStart = elapsed;
            while (elapsed - phaseStart < halfPeriod)
            {
                elapsed += Time.deltaTime;
                yield return null;
            }
        }
        gameObject.SetActive(false);
    }
}
